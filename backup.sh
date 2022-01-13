#!/bin/bash

printHelper() {
    printf "\n$1 ($(date +'%F %T')) %-10s: $3\n" "$2"
}

printError() {
    printHelper "🔴" "ERROR" "$1"
}

printInfo() {
    printHelper "🔵" "INFO" "$1"
}

printSuccess() {
    printHelper "🟢" "SUCCESS" "$1"
}

printImportant() {
    printHelper "🔶" "IMPORTANT" "$1"
}

checkAllEnvironmentVariables() {
    local envError=false
    [ "$PINGURL" == "" ] && envError=true
    [ "$DOCKERDIR" == "" ] && envError=true
    [ "$BACKUPDIR" == "" ] && envError=true
    [ "$PCLOUDLOCATION" == "" ] && envError=true
    [ "$RESTIC_PASSWORD_FILE" == "" ] && envError=true
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
    # No stdout print because file is backing up
    rclone sync "$BACKUPDIR"/logs/ pcloud:"$PCLOUDLOCATION"logs
}

backupMediaFolderIfExternalExisting() {
    externalFolder="/media/external/media/"
    localMediaFolder="/home/flohoss/media/"
    if [[ -d "$externalFolder" ]]
    then
        printImportant "Backup media folder"
        rclone sync "$localMediaFolder" "$externalFolder"
        checkNoError "$?" "Backup media folder"
    fi
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

checkNoError() {
    if [ "$1" -ne 0 ]; then
        curl -sS --data-raw "$2" "$PINGURL"/fail
        printError "$2"
        _returnVar="error"
    else
        printSuccess "$2"
        _returnVar="success"
    fi
}

resticInit() {
    printInfo "Preparing a new repository of <$folderName>"
    restic init
    checkNoError "$?" "restic prepare"
    sleep 5
}

resticCheckIfRepoExists() {
    restic snapshots >/dev/null 2>&1
    if [ "$?" -ne 0 ]; then
        resticInit
    fi
}

resticCopy() {
    resticCheckIfRepoExists
    printInfo "Restic Backup of <$folderName>"
    restic backup "$location"
    checkNoError "$?" "restic backup"
}

resticCleanup() {
    printInfo "Restic Cleanup of <$folderName>"
    restic forget --keep-within-daily 7d --keep-within-weekly 1m --keep-within-monthly 1y --keep-within-yearly 75y --prune
    checkNoError "$?" "restic cleanup"
}

resticCacheCleanup() {
    restic cache --cleanup >/dev/null 2>&1
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

initScriptEnv() {
    location="$1"
    folderName="$(echo $location | rev | cut -d'/' -f2 | rev)"
    printImportant "Backing up <$location>"
    export RESTIC_REPOSITORY="rclone:pcloud:$PCLOUDLOCATION$folderName"
}

directoryBackup() {
    initScriptEnv "$1"
    resticCopy
    # only continue each step if the previous step has not caused an error
    [ "$_returnVar" != "error" ] && resticCleanup
    resetReturnVar
}

resetReturnVar() {
    _returnVar=""
}

goThroughDockerDirectorys() {
    for location in $DOCKERDIR*/; do
        initScriptEnv "$location"
        chooseForegoingAction
        # only continue each step if the previous step has not caused an error
        [ "$_returnVar" != "error" ] && resticCopy
        [ "$_returnVar" != "error" ] && chooseSubsequentAction
        [ "$_returnVar" != "error" ] && resticCleanup
        resetReturnVar
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
backupMediaFolderIfExternalExisting
healthFinish
backupLogs
