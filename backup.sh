#!/bin/bash

source "$HELPER_LOCATION"

checkAllEnvironmentVariables() {
    printInfo "Checking if all environment variables are set"
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

backupCurrentCrontab() {
    crontab -l >"$BACKUPDIR"currentCrontabBackup.txt
    checkNoError "$?" "contab backup"
}

backupLogs() {
    # No stdout print because file is backing up
    rclone sync "$BACKUPDIR"/logs/ pcloud:"$PCLOUDLOCATION"logs
}

backupMediaFolderIfExternalExisting() {
    if [ "$EXTERNALMEDIAFOLDER" != "" ] && [ "$LOCALMEDIAFOLDER" != "" ]; then
        printImportant "$1"
        rclone sync "$LOCALMEDIAFOLDER" "$EXTERNALMEDIAFOLDER"
        checkNoError "$?" "$1"
    else
        printInfo "No media folder backup executed"
    fi
}

healthStart() {
    printInfo "$1"
    curl -sS -o /dev/null "$PINGURL"/start
    checkNoError "$?" "$1"
}

healthFinish() {
    printInfo "$1"
    curl -sS -o /dev/null "$PINGURL"
    checkNoError "$?" "$1"
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

# Specify what docker should be stopped before backing them up, seperate with space
dockerToStop="gitea hedgedoc sharelatex vaultwarden media firefly"

printImportant "backup.sh"
checkSudoRights
checkAllEnvironmentVariables
healthStart "Sending START curl"
resticCacheCleanup
backupCurrentCrontab
printAllImageVersions
goThroughDockerDirectorys
directoryBackup "/opt/backup/"
backupMediaFolderIfExternalExisting "Backup media folder"
healthFinish "Sending STOP curl"
backupLogs
