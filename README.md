![](https://img.shields.io/badge/Basics-Shell-informational?style=for-the-badge&logo=gnubash&color=4EAA25)
![](https://img.shields.io/badge/OS-Debian-informational?style=for-the-badge&logo=debian&color=A81D33)
![](https://img.shields.io/badge/Tech-Docker-informational?style=for-the-badge&logo=docker&color=2496ED)
![](https://img.shields.io/badge/Hoster-Hetzner-informational?style=for-the-badge&logo=hetzner&color=D50C2D)

# Backup-script to run in linux with restic, rclone and pcloud

Make sure to install docker compose V2 globally if you are running the script as root:

```bash
mkdir -p /usr/local/lib/docker/cli-plugins
curl -SL https://github.com/docker/compose/releases/download/v2.0.1/docker-compose-linux-x86_64 -o /usr/local/lib/docker/cli-plugins/docker-compose
chmod +x /usr/local/lib/docker/cli-plugins/docker-compose
```

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

## environment variables used in the script (specify in /etc/environment)

```bash
PINGURL="https://healthchecks"
DOCKERDIR="/opt/docker/"
BACKUPDIR="/opt/backup/"
PCLOUDLOCATION="Backups/example/"
```