#!/bin/bash

printHelper() {    
    printf "\n$1: ($(date +%H:%M:%S)) $2\n"
}

printError() {
    printHelper "🔴 ERROR 🔴" "$1"
}

printInfo() {
    printHelper "ℹ️ INFO ℹ️" "$1"
}

printSuccess() {
    printHelper "🟢 SUCCESS 🟢" "$1"
}

printImportant() {
    printHelper "🔔 IMPORTANT 🔔" "$1"
}

checkAllEnvironmentVariables() {
    local envError=false
    [ "$PINGURL" == "" ] && envError=true
    [ "$DOCKERDIR" == "" ] && envError=true
    [ "$BACKUPDIR" == "" ] && envError=true
    [ "$PCLOUDLOCATION" == "" ] && envError=true
    if [ "$envError" = true ]; then
        printError "Some environmet variables are not set"
        exit 1
    else
        printSuccess "All environmet variables are set"
    fi
}

checkSudoRights() {
    [ "$EUID" -ne 0 ] && printError "This script must be run as root" && exit 1
}

backupCurrentCrontab() {
    crontab -l > "$BACKUPDIR"currentCrontabBackup.txt
    checkNoError "$?" "contab backup"
}

backupLogs() {
    rclone sync "$BACKUPDIR"/logs/ pcloud:"$PCLOUDLOCATION"logs
}

healthStart() {
    printInfo "Sending START ping to healthchecks"
    curl -sS -o /dev/null "$PINGURL"/start
    checkNoError "$?" "start ping"
}

healthFinish() {
    printInfo "Sending STOP ping to healthchecks"
    curl -sS -o /dev/null "$PINGURL"
    checkNoError "$?" "stop ping"
}

checkResticError() {
    if [ "$1" -eq 1 ]; then
        curl -sS --data-raw "restic fatal error" "$PINGURL"/fail
        printError "Restic fatal"
    elif [ "$1" -eq 2 ]; then
        curl -sS --data-raw "restic remaining files" "$PINGURL"/fail
        printError "Restic remaining files"
    else
        printSuccess "Restic operation complete"
    fi
}

checkNoError() {
    if [ "$1" -ne 0 ]; then
        curl -sS --data-raw "$2 error" "$PINGURL"/fail
        printError "$2"
        functionReturn="error"
    else
        printSuccess "$2"
        functionReturn=""
    fi
}

resticCopy() {
    printInfo "Restic Start Backup: $folderName"
    restic -r rclone:pcloud:"$PCLOUDLOCATION""$folderName" backup "$DOCKERDIR""$folderName" --password-file /opt/backup/.resticpwd
    checkResticError "$?"
}

resticCleanup() {
    printInfo "Restic Start Cleanup: $folderName"
    restic -r rclone:pcloud:"$PCLOUDLOCATION""$folderName" forget --keep-daily 7 --keep-weekly 5 --keep-monthly 12 --keep-yearly 75 --prune --password-file /opt/backup/.resticpwd
    checkResticError "$?"
}

resticCacheCleanup() {
    restic cache --cleanup
    checkNoError "$?" "restic cache cleanup"
}

getImageVersion() {
    printf "%s:" "$1"
    if [ "$(docker inspect -f '{{ index .Config.Labels "org.opencontainers.image.authors" }}' "$1")" = "linuxserver.io" ]; then
    	docker inspect -f '{{ index .Config.Labels "build_version" }}' "$1"
    else
        docker inspect --format='{{.Config.Image}}' "$1"
    fi
}

printAllImageVersions() {
    printInfo "Print docker container versions"
    for Docker in $(docker ps --format '{{.Names}}')
    do
      getImageVersion "$Docker"
    done
}

directoryBackup() {
    directory="$1"
    folderName="$(echo $directory | rev | cut -d'/' -f2 | rev)"
    resticCopy
    resticCleanup
}

stopDockerCompose() {
    cd "$directory" && docker compose stop
    checkNoError "$?" "docker compose $folderName stop"
    if [ functionReturn != "" ]
}

startDockerCompose() {
    cd "$directory" && docker compose up -d
    checkNoError "$?" "docker compose $folderName start"
}

turnOnNextcloudMaintenanceMode() {
    docker exec nextcloud occ maintenance:mode --on
    checkNoError "$?" "nextcloud maintenance mode on"
}

turnOffNextcloudMaintenanceMode() {
    docker exec nextcloud occ maintenance:mode --off
    checkNoError "$?" "nextcloud maintenance mode off"
}

chooseForegoingAction() {
    if echo $dockerToStop | grep -w $folderName > /dev/null; then
        stopDockerCompose
    elif [ "$folderName" == "nextcloud" ]; then
        turnOnNextcloudMaintenanceMode
    fi
}

chooseSubsequentAction() {
    if echo $dockerToStop | grep -w $folderName > /dev/null; then
        startDockerCompose
    elif [ "$folderName" == "nextcloud" ]; then
        turnOffNextcloudMaintenanceMode
    fi
}

goThroughDockerDirectorys() {
    for directory in $DOCKERDIR*/
    do
        folderName="$(echo $directory | rev | cut -d'/' -f2 | rev)"
        printImportant "Backing up $folderName"
        chooseForegoingAction
        resticCopy
        chooseSubsequentAction
        resticCleanup
    done
}

# Specify what docker should be stopped before backing them up, seperate with space
dockerToStop="gitea hedgedoc node-red sharelatex vaultwarden media"

# Start of the sequence
checkSudoRights
checkAllEnvironmentVariables
healthStart
resticCacheCleanup
backupCurrentCrontab
printAllImageVersions
goThroughDockerDirectorys
directoryBackup "/opt/backup/"
healthFinish
backupLogs