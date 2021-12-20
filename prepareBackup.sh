#!/bin/bash

printHelper() {
    printf "\n$1 %-10s $1 ($(date +'%F %T')) $3\n" "$2"
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

checkSudoRights() {
    [ "$EUID" -ne 0 ] && printError "This script must be run as root" && exit 1
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

pullGithubRepo() {
    printInfo "Pull current github repository"
    cd /opt/backup/ && git pull --no-rebase
    checkNoError "$?" "pull github"
}

setCrontab() {
    printInfo "Set crontab to crontab.txt"
    crontab /opt/backup/crontab.txt
    checkNoError "$?" "set crontab"
}

setEnvironment() {
    printInfo "Set all environment variables"
    cd /opt/backup/ && cat .environment > /etc/environment
    checkNoError "$?" "set environment"
}

createLogFolderStructure() {
    printInfo "Create log folder structure"
    cd /opt/backup/ && mkdir "$backupParentDir"logs/$(date +\%Y)/$(date +\%m)/ -p
    checkNoError "$?" "create log folder"
}

checkSudoRights

pullGithubRepo
setCrontab
setEnvironment
createLogFolderStructure