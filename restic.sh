#!/bin/bash

action=$1
repo=$2
option=$3

checkSudoRights() {
    [ "$EUID" -ne 0 ] && printError "This script must be run as root" && exit 1
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

checkSudoRights
checkAllEnvironmentVariables

case $action in
    "snapshots" )
	    restic -r rclone:pcloud:"$PCLOUDLOCATION""$repo" snapshots --password-file /opt/backup/.resticpwd
        ;;
    "remove" )
	    restic -r rclone:pcloud:"$PCLOUDLOCATION""$repo" forget "$option" --prune --password-file /opt/backup/.resticpwd
        ;;
    "keep-last" )
	    restic -r rclone:pcloud:"$PCLOUDLOCATION""$repo" forget --keep-last "$option" --prune --password-file /opt/backup/.resticpwd
        ;;
    "init" )
	    restic -r rclone:pcloud:"$PCLOUDLOCATION""$repo" init --password-file /opt/backup/.resticpwd
        ;;
    "restore" )
	    restic -r rclone:pcloud:"$PCLOUDLOCATION""$repo" restore "$option" --target /tmp/ --password-file /opt/backup/.resticpwd
        ;;
    *)
        printf "🔔 HOW-TO 🔔\n\n"
        printf "snapshots 	[repo]\n"
        printf "remove 		[repo] 		[snapshot-id]\n"
        printf "keep-last 	[repo] 		[amount]\n"
        printf "init 		[repo]\n"
        printf "restore 	[repo] 		[latest/snapshot-id]\n"
        exit 1
esac