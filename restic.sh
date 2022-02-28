#!/bin/bash

cd "$BACKUPDIR" && source "helpers.sh"

checkAllEnvironmentVariables() {
    printInfo "Checking if all environment variables are set"
    local envError=false
    [ "$PCLOUDLOCATION" == "" ] && envError=true
    if [ "$envError" = true ]; then
        printError "Some environmet variables are not set"
        exit 1
    else
        printSuccess "All environmet variables are set"
    fi
}

printOption() {
    printf "\n✨ %s:\n%-10s%-10s%-10s\n" "$1" "$2" "$3" "$4"
}

action=$1
repo=$2
option=$3

checkSudoRights
checkAllEnvironmentVariables

case $action in
"snapshots")
    printInfo "Show restic shapshots"
    restic -r rclone:pcloud:"$PCLOUDLOCATION""$repo" snapshots
    checkNoError "$?" "Show restic snapshots"
    ;;
"remove")
    printInfo "Remove restic shapshot"
    restic -r rclone:pcloud:"$PCLOUDLOCATION""$repo" forget "$option" --prune
    checkNoError "$?" "Remove restic snapshot"
    ;;
"keep-last")
    printInfo "Remove all, keep last restic shapshot"
    restic -r rclone:pcloud:"$PCLOUDLOCATION""$repo" forget --keep-last "$option" --prune
    checkNoError "$?" "Remove all, keep last restic shapshot"
    ;;
"init")
    printInfo "Init restic repository"
    restic -r rclone:pcloud:"$PCLOUDLOCATION""$repo" init
    checkNoError "$?" "Init restic repository"
    ;;
"restore")
    printInfo "Restore restic repository"
    restic -r rclone:pcloud:"$PCLOUDLOCATION""$repo" restore "$option" --target /tmp/
    checkNoError "$?" "Restore restic repository"
    ;;
"rebuild")
    printInfo "Rebuild restic indexes"
    restic -r rclone:pcloud:"$PCLOUDLOCATION""$repo" rebuild-index
    checkNoError "$?" "Rebuild restic indexes"
    ;;
*)
    printInfo "HOW-TO"
    printOption "Show snapshots" "snapshots" "[repo]" ""
    printOption "Remove Snapshot" "remove" "[repo]" "[snapshot-id]"
    printOption "Remove snapshots and keep amount" "keep-last" "[repo]" "[amount]"
    printOption "Init repo" "init" "[repo]" ""
    printOption "Restore snapshot" "restore" "[repo]" "[latest/snapshot-id]"
    printOption "Rebuild repo" "rebuild" "[repo]" ""
    exit 1
    ;;
esac
