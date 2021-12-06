#!/bin/sh

# pull current github repository
cd /opt/backup/ && git pull --no-rebase
# overwrite crontab with crontab.txt
crontab /opt/backup/crontab.txt
# create a folder structure for logs
mkdir "$backupParentDir"logs/$(date +\%Y)/$(date +\%m)/ -p
