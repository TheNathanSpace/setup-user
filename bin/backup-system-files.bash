#!/usr/bin/env bash

# A script to backup various (hardcoded) system files. The intent is to just
# add new backup locations and their associated logic at the bottom of the script.
#
# Ideally, the files you're backing up are small enough (e.g., text configs)
# that it doesn't really matter if they're backed up unnecessarily. For example,
# if I have a system with no cron jobs, I don't care that cron configuration is
# backed up. But, there's not really any harm in including it in the backup, because
# otherwise you'd have to customize this script for every single system it's
# deployed on.
#
# Arguments:
#     --parent-path
#     --username

# We require root because we'll be backing up and changing permissions of some system config files.
if [ "$(id -u)" -ne 0 ]; then echo "Error: Please run as root." >&2; exit 1; fi

# Parse command line options
PARENT_PATH=""
USERNAME=""
while [[ $# -gt 0 ]]; do
    case $1 in
        --parent-path)
            SYSTEM_FILES_BACKUP_DIR="$2"
            shift 2
            ;;
        --username)
            USERNAME="$2"
            shift 2
            ;;
        *)
            echo "Unknown parameter: $1"
            ;;
    esac
done
if [[ -z "$USERNAME" ]]; then
    echo "Warning: --username parameter not provided. Using 'nathan'."
    USERNAME="nathan"
fi
if [[ -z "$SYSTEM_FILES_BACKUP_DIR" ]]; then
    echo "Warning: --parent-path parameter not provided. Using /home/$USERNAME/backups/system-files"
    SYSTEM_FILES_BACKUP_DIR="/home/$USERNAME/backups/system-files"
fi

# Create the backup directory
mkdir -p "$SYSTEM_FILES_BACKUP_DIR"

CURRENT_SCRIPT_TIME="$(date +%Y%m%d-%H%M%S)"

# Backup the system's cron jobs
CRONTAB_DIR="$SYSTEM_FILES_BACKUP_DIR/crontab"
/home/"$USERNAME"/bin/backup-crontab.sh --backup-path "$CRONTAB_DIR"

# Backup the systems /etc/fstab file, storing the drive mounting configuration
FSTAB_DIR="$SYSTEM_FILES_BACKUP_DIR/fstab"
mkdir -p "$FSTAB_DIR"
FSTAB_BACKUP_FILE="$FSTAB_DIR/${CURRENT_SCRIPT_TIME}_fstab"
cp "/etc/fstab" "$FSTAB_BACKUP_FILE"

################################################################################
#    You would add additional backup locations and their logic around here.    #
################################################################################

# Recursively update the permissions of all backed up files
chown -R "$USERNAME:$USERNAME" "$SYSTEM_FILES_BACKUP_DIR"
chmod -R 644 "$SYSTEM_FILES_BACKUP_DIR"

# Directories require executable permissions for the user to view them
find "$SYSTEM_FILES_BACKUP_DIR" -type d -exec chmod 750 {} ';'
