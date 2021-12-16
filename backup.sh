#!/bin/bash

printHelper() {
    printf "\n$1 %-10s $1 ($(date +'%F %T')) $3\n" "$2"
}

printError() {
    printHelper "🔴" "ERROR" "$1"
}

printInfo() {
    printHelper "🟠" "INFO" "$1"
}

printSuccess() {
    printHelper "🟢" "SUCCESS" "$1"
}

printImportant() {
    printHelper "🔔" "IMPORTANT" "$1"
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
    crontab -l >"$BACKUPDIR"currentCrontabBackup.txt
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
        _returnVar="error"
    elif [ "$1" -eq 2 ]; then
        curl -sS --data-raw "restic remaining files" "$PINGURL"/fail
        printError "Restic remaining files"
        _returnVar="error"
    else
        printSuccess "Restic operation complete"
        _returnVar="success"
    fi
}

checkNoError() {
    if [ "$1" -ne 0 ]; then
        curl -sS --data-raw "$2 error" "$PINGURL"/fail
        printError "$2"
        _returnVar="error"
    else
        printSuccess "$2"
        _returnVar="success"
    fi
}

resticCopy() {
    printInfo "Restic Backup of <$folderName>"
    restic -r rclone:pcloud:"$PCLOUDLOCATION""$folderName" backup "$location" --password-file /opt/backup/.resticpwd
    checkResticError "$?"
}

resticCleanup() {
    printInfo "Restic Cleanup of <$folderName>"
    restic -r rclone:pcloud:"$PCLOUDLOCATION""$folderName" forget --keep-daily 7 --keep-weekly 5 --keep-monthly 12 --keep-yearly 75 --prune --password-file /opt/backup/.resticpwd
    checkResticError "$?"
}

resticCacheCleanup() {
    restic cache --cleanup >/dev/null
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
    for Docker in $(docker ps --format '{{.Names}}'); do
        getImageVersion "$Docker"
    done
}

directoryBackup() {
    location="$1"
    folderName="$(echo $location | rev | cut -d'/' -f2 | rev)"
    printImportant "Backing up <$location>"
    resticCopy
    # only continue each step if the previous step has not caused an error
    [ "$_returnVar" != "error" ] && resticCleanup
}

teleportConfigBackup() {
    location="$1"
    folderName="$(echo $location | rev | cut -d'/' -f2 | rev | cut -d'.' -f1)"
    printImportant "Backing up <$location>"
    resticCopy
    # only continue each step if the previous step has not caused an error
    [ "$_returnVar" != "error" ] && resticCleanup
}

stopDockerCompose() {
    cd "$location" && docker compose stop
    checkNoError "$?" "docker compose $folderName stop"
}

startDockerCompose() {
    cd "$location" && docker compose start
    checkNoError "$?" "docker compose $folderName start"
}

turnOnNextcloudMaintenanceMode() {
    docker exec nextcloud occ maintenance:mode --on >/dev/null
    checkNoError "$?" "nextcloud maintenance mode on"
}

turnOffNextcloudMaintenanceMode() {
    docker exec nextcloud occ maintenance:mode --off >/dev/null
    checkNoError "$?" "nextcloud maintenance mode off"
}

chooseForegoingAction() {
    if echo $dockerToStop | grep -w $folderName >/dev/null; then
        stopDockerCompose
    elif [ "$folderName" == "nextcloud" ]; then
        turnOnNextcloudMaintenanceMode
    fi
}

chooseSubsequentAction() {
    if echo $dockerToStop | grep -w $folderName >/dev/null; then
        startDockerCompose
    elif [ "$folderName" == "nextcloud" ]; then
        turnOffNextcloudMaintenanceMode
    fi
}

goThroughDockerDirectorys() {
    for location in $DOCKERDIR*/; do
        folderName="$(echo $location | rev | cut -d'/' -f2 | rev)"
        printImportant "Backing up <$location>"
        chooseForegoingAction
        # only continue each step if the previous step has not caused an error
        [ "$_returnVar" != "error" ] && resticCopy
        [ "$_returnVar" != "error" ] && chooseSubsequentAction
        [ "$_returnVar" != "error" ] && resticCleanup
        # reset returnVar for next run
        _returnVar=""
    done
}

# Global return variable
_returnVar=""

# Specify what docker should be stopped before backing them up, seperate with space
dockerToStop="gitea hedgedoc sharelatex vaultwarden media"

# Start of the sequence
checkSudoRights
checkAllEnvironmentVariables
healthStart
resticCacheCleanup
backupCurrentCrontab
printAllImageVersions
goThroughDockerDirectorys
directoryBackup "/opt/backup/"
teleportConfigBackup "/etc/teleport.yaml"
healthFinish
backupLogs
