#!/bin/bash

printHelper() {
    printf "\n$1 ($(date +'%F %T')) %-10s: $3\n" "$2"
}

printError() {
    printHelper "🔴" "ERROR" "$1"
}

printSuccess() {
    printHelper "🟢" "SUCCESS" "$1"
}

printImportant() {
    printHelper "🔶" "IMPORTANT" "$1"
}

checkAllEnvironmentVariables() {
    local envError=false
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

action=$1
repo=$2
option=$3

checkSudoRights
checkAllEnvironmentVariables

case $action in
"snapshots")
    printImportant "Show restic shapshots"
    restic -r rclone:pcloud:"$PCLOUDLOCATION""$repo" snapshots
    checkNoError "$?" "Show restic snapshots"
    ;;
"remove")
    printImportant "Remove restic shapshot"
    restic -r rclone:pcloud:"$PCLOUDLOCATION""$repo" forget "$option" --prune
    checkNoError "$?" "Remove restic snapshot"
    ;;
"keep-last")
    printImportant "Remove all, keep last restic shapshot"
    restic -r rclone:pcloud:"$PCLOUDLOCATION""$repo" forget --keep-last "$option" --prune
    checkNoError "$?" "Remove all, keep last"
    ;;
"init")
    printImportant "Init restic repository"
    restic -r rclone:pcloud:"$PCLOUDLOCATION""$repo" init
    checkNoError "$?" "Init restic repository"
    ;;
"restore")
    printImportant "Restore restic repository"
    restic -r rclone:pcloud:"$PCLOUDLOCATION""$repo" restore "$option" --target /tmp/
    checkNoError "$?" "Restore restic repository"
    ;;
*)
    printImportant "HOW-TO"
    printf "snapshots 	[repo]\n"
    printf "remove 		[repo] 		[snapshot-id]\n"
    printf "keep-last 	[repo] 		[amount]\n"
    printf "init 		[repo]\n"
    printf "restore 	[repo] 		[latest/snapshot-id]\n"
    exit 1
    ;;
esac
