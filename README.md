# Backup-script to run in linux with restic, rclone and pcloud

! Make sure to install docker-compose globally if you are running the script as root !

A working rclone config file is needed. Feel free to change the backup function to your favoured backup command.

This script will go through all the folders in, for example, /opt/docker/ and execute a docker-compose stop command to run a backup to a remote pCloud location. The stop command only happens if the docker folder has been specified in the list to be stopped before backup. If the docker folder is called nextcloud it will enable maintenance mode as long as the backup is running. The restic repository in pCloud will need to be initialized before this script is run. For performance reasons the initialization has been excluded from the daily routine.

Once the script is running without errors, the crontab example can be used to run it every night and create logs in a separate folder.

## example folder structure

```
/opt/
│
└─── docker/
│   │
│   └─── nextcloud/
│   │   │  docker-compose.yml
│   │   │  ...
│   │
│   └─── gitea/
│       │  docker-compose.yml
│       │  ...
│   
└─── backup/
    │  backup.sh
    │  createLogsFolder.sh
    │  ...
    └─── logs/
        └─── 2021/
        │   └─── ...
        │   └─── 10/
        │   │   └─── ...
        │   │   └─── 2021-10-06.txt
        │   │   └─── ...
        │   └─── 11/
        │   └─── ...
        └─── 2022/
            └─── ...
            └─── 10/
            └─── 11/
            │   └─── ...
            │   └─── 2022-11-06.txt
            │   └─── ...
            └─── ...
```

## environment variables used in the script (specify in /etc/environment)

```
PINGURL="https://healthchecks"
DOCKERDIR="/opt/docker/"
BACKUPDIR="/opt/backup/"
PCLOUDLOCATION="Backups/example/"
```