#!/bin/bash

source "helpers.sh"

pullGithubRepo() {
    printInfo "$1"
    cd /opt/backup/ && git pull --no-rebase
    checkNoError "$?" "$1"
}

setCrontab() {
    printInfo "$1"
    crontab /opt/backup/crontab.txt
    checkNoError "$?" "$1"
}

setEnvironment() {
    printInfo "$1"
    cd /opt/backup/ && cat .environment > /etc/environment
    checkNoError "$?" "$1"
}

checkSudoRights

pullGithubRepo "Pull current github repository"
setCrontab "Set crontab to crontab.txt"
setEnvironment "Set all environment variables"
