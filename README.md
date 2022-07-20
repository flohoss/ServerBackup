![](https://img.shields.io/badge/Basics-Shell-informational?style=for-the-badge&logo=gnubash&color=4EAA25)

# Backup-script to run in linux with restic, rclone and pcloud

Make sure to install **docker compose V2 globally** if you are running the script as root:

[https://docs.docker.com/compose/cli-command/](https://docs.docker.com/compose/cli-command/)

A working rclone config file is needed. Feel free to change the backup function to your favoured backup command.

This script will go through all the folders in, for example, /opt/docker/ and execute a docker-compose stop command to run a backup to a remote pCloud location. The stop command only happens if the docker folder has been specified in the list to be stopped before backup. If the docker folder is called nextcloud it will enable maintenance mode as long as the backup is running. The restic repository in pCloud will be initialized before every backup run.

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
    │  -rwxr-xr-x root:root backup.sh
    │  -rw-r--r-- root:root crontab.txt
    │  -rw------- root:root .environment
    │  -rwxr-xr-x root:root prepareBackup.sh
    │  -rw------- root:root .resticpwd
    │  -rwxr-xr-x root:root restic.sh
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

## environment variables used in the script

```prepareBackup.sh``` will copy ```.environment``` in ```/etc/environment```

```bash
PINGURL="https://health.example.de/ping/<health_check_ping_id>"
DOCKERDIR="/opt/docker/"
BACKUPDIR="/opt/backup/"
PCLOUDLOCATION="Backups/server1/"
RESTIC_PASSWORD_FILE="/opt/backup/.resticpwd"
```
