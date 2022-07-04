#!/bin/bash

cd "$BACKUPDIR" && source "helpers.sh"

pullGithubRepo() {
    cd /opt/backup/ && git pull --no-rebase
    checkNoError "$?" "Pull current github repository"
}

setCrontab() {
    crontab /opt/backup/crontab.txt
    checkNoError "$?" "Set crontab to crontab.txt"
}

setEnvironment() {
    cd /opt/backup/ && cat .environment > /etc/environment
    checkNoError "$?" "Set all environment variables"
}

export PATH=$PATH:/usr/bin/rclone
printImportant "prepareBackup.sh"
checkSudoRights
pullGithubRepo
setCrontab
setEnvironment
