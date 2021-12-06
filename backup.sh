#!/bin/bash

printHelper() {    
    printf "\n$1: ($(date +%H:%M:%S)) $2\n"
}

printError() {
    printHelper "🔴 ERROR" "$1"
}

printInfo() {
    printHelper "🟡 INFO" "$1"
}

printSuccess() {
    printHelper "🟢 SUCCESS" "$1"
}

printImportant() {
    printHelper "⬛ IMPORTANT" "$1"
}

checkAllEnvironmentVariables() {
    envError=false
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
}

healthFinish() {
    printInfo "Sending STOP ping to healthchecks"
    curl -sS -o /dev/null "$PINGURL"
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
    else
        printSuccess "$2"
    fi
}

resticCopy() {
    printInfo "Restic Start Backup: $1"
    restic -r rclone:pcloud:"$PCLOUDLOCATION""$1" backup "$2""$1" --password-file /opt/backup/.resticpwd
    checkResticError "$?"
}

resticCleanup() {
    printInfo "Restic Start Cleanup: $1"
    restic -r rclone:pcloud:"$PCLOUDLOCATION""$1" forget --keep-daily 7 --keep-weekly 5 --keep-monthly 12 --keep-yearly 75 --prune --password-file /opt/backup/.resticpwd
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
    resticCopy "$1" "$2"
    resticCleanup "$1"
}

nextcloudBackup() {
    docker exec nextcloud occ maintenance:mode --on
    resticCopy "$1" "$2" "$3"
    resticCleanup "$1" "$2"
    docker exec nextcloud occ maintenance:mode --off
}

stopDockerCompose() {
    cd "$1" && docker-compose stop
    checkNoError "$?" "docker-compose $2 stop"
}

startDockerCompose() {
    cd "$1" && test -r docker-compose.yml && docker-compose up -d
    checkNoError "$?" "docker-compose $2 start"
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
    if echo $dockerToStop | grep -w $1 > /dev/null; then
        stopDockerCompose "$2" "$1"
    elif [ "$1" == "nextcloud" ]; then
        turnOnNextcloudMaintenanceMode
    fi
}

chooseSubsequentAction() {
    if echo $dockerToStop | grep -w $1 > /dev/null; then
        startDockerCompose "$2" "$1"
    elif [ "$1" == "nextcloud" ]; then
        turnOffNextcloudMaintenanceMode
    fi
}

goThroughDockerDirectorys() {
    for directory in $DOCKERDIR*/
    do
        folderName="$(echo $directory | rev | cut -d'/' -f2 | rev)"
        printImportant "Backing up $folderName"
        chooseForegoingAction "$folderName" "$directory"
        resticCopy "$folderName" "$DOCKERDIR"
        chooseSubsequentAction "$folderName" "$directory"
        resticCleanup "$folderName"
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
directoryBackup "backup" "/opt/"
healthFinish
backupLogs