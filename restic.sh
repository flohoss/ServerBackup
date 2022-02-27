#!/bin/bash

source "helpers.sh"

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
    printf "Show snapshots:\n"
    printf "    snapshots 	    [repo]\n\n"
    printf "Remove Snapshot:\n"
    printf "    remove 		    [repo] 		[snapshot-id]\n\n"
    printf "Remove snapshots and keep amount:\n"
    printf "    keep-last 	    [repo] 		[amount]\n\n"
    printf "Init repo:\n"
    printf "    init 		    [repo]\n\n"
    printf "Restore snapshot:\n"
    printf "    restore 	    [repo] 		[latest/snapshot-id]\n\n"
    printf "Rebuild repo:\n"
    printf "    rebuild 	    [repo]\n\n"
    exit 1
    ;;
esac
