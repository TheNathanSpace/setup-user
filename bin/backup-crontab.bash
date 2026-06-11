#!/usr/bin/env bash

BACKUP_ARCHIVE_PATH=""

while [[ $# -gt 0 ]]; do
    case $1 in
        --backup-path)
            BACKUP_ARCHIVE_PATH="$2"
            shift 2
            ;;
        *)
            echo "Unknown parameter: $1"
            ;;
    esac
done

if [[ -z "$BACKUP_ARCHIVE_PATH" ]]; then
    echo "Error: --backup-path parameter is required"
    exit 1
fi

mkdir "$BACKUP_ARCHIVE_PATH" -p
chown -R nathan:nathan "$BACKUP_ARCHIVE_PATH"
BASE_BACKUP_NAME="$BACKUP_ARCHIVE_PATH/crontab-backup-$CURRENT_SCRIPT_TIME"

CURRENT_SCRIPT_TIME="$(date +%Y%m%d-%H%M%S)"
BACKUP_DIR="$BASE_BACKUP_NAME"
mkdir "$BACKUP_DIR" -p
cd "$BACKUP_DIR"

mkdir --parents ./etc/default
mkdir --parents ./var/spool/
cp -a /etc/crontab ./etc/crontab
cp -a /etc/anacrontab ./etc/anacrontab

for cron_dir in /etc/cron.*; do
    [ -e "$cron_dir" ] && cp -a "$cron_dir" ./etc/
done

cp -a /etc/default/cron ./etc/default/cron
cp -a /etc/default/anacron ./etc/default/anacron
cp -a /var/spool/cron ./var/spool/
cp -a /var/spool/anacron ./var/spool/

cd ..
ZIP_NAME="${BASE_BACKUP_NAME}.zip"
zip -r "$ZIP_NAME" "$BACKUP_DIR"

chown nathan:nathan "$ZIP_NAME"
chmod 644 "$ZIP_NAME"

rm -rf "$BACKUP_DIR"
