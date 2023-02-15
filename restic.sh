#!/bin/bash

cd "$BACKUPDIR" && source "helpers.sh"

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
"unlock")
    printInfo "Unlocking restic repository"
    restic -r rclone:pcloud:"$PCLOUDLOCATION""$repo" unlock
    checkNoError "$?" "Unlocking restic repository"
    ;;
"upgrade")
    printInfo "Upgrading restic repository"
    restic -r rclone:pcloud:"$PCLOUDLOCATION""$repo" migrate upgrade_repo_v2
    checkNoError "$?" "Upgrading restic repository"
    restic -r rclone:pcloud:"$PCLOUDLOCATION""$repo" prune
    checkNoError "$?" "Pruning restic repository"
    ;;
"check")
    printInfo "Checking restic repository"
    restic -r rclone:pcloud:"$PCLOUDLOCATION""$repo" check
    checkNoError "$?" "Checking restic repository"
    ;;
"passwd")
    printInfo "Changing restic repository key"
    restic -r rclone:pcloud:"$PCLOUDLOCATION""$repo" key passwd
    checkNoError "$?" "Checking restic repository"
    ;;
"keys")
    printInfo "List restic repository keys"
    restic -r rclone:pcloud:"$PCLOUDLOCATION""$repo" key list
    checkNoError "$?" "Checking restic repository"
    ;;
*)
    printInfo "HOW-TO"
    printOption "Show snapshots" "snapshots" "[repo]" ""
    printOption "Remove Snapshot" "remove" "[repo]" "[snapshot-id]"
    printOption "Remove snapshots and keep amount" "keep-last" "[repo]" "[amount]"
    printOption "Init repo" "init" "[repo]" ""
    printOption "Restore snapshot" "restore" "[repo]" "[latest/snapshot-id]"
    printOption "Rebuild repo" "rebuild" "[repo]" ""
    printOption "Unlock repo" "unlock" "[repo]" ""
    printOption "Upgrade repo" "upgrade" "[repo]" ""
    printOption "Check repo" "check" "[repo]" ""
    printOption "Change key" "passwd" "[repo]" ""
    printOption "List keys" "keys" "[repo]" ""
    exit 1
    ;;
esac
