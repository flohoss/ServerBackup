#!/bin/bash

cd "$BACKUPDIR" && source "helpers.sh"

pullGithubRepo() {
    cd /opt/backup/ && git pull --no-rebase
    checkNoError "$?" "Pull current github repository"
}

setCrontab() {
    crontab /opt/backup/crontab.txt
    checkNoError "$?" "Save crontab to crontab.txt"
}

setEnvironment() {
    cd /opt/backup/ && cat .environment > /etc/environment
    checkNoError "$?" "Set all environment variables"
}

printImportant "prepareBackup.sh"
checkSudoRights
pullGithubRepo
setCrontab
setEnvironment
