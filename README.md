# Backup-script to run on a server with restic, rclone and pcloud

## folder structure

```
opt
│
└─── docker/
│   └─── proxy/
│   │   │  docker-compose.yml
│   └─── gitea/
│   │   │  docker-compose.yml
└─── backup/
│   │   backup.sh
│   │   createLogsFolder.sh
```

## needed environment variables (specify in /etc/environment)

PINGURL="https://healthchecks"
DOCKERDIR="/opt/docker/"
BACKUPDIR="/opt/backup/"
PCLOUDLOCATION="Backups/example/"