#!/bin/bash

configureBackup() {
    echo "*** Configure backup..."

    echo "     o create backup directory $backupLocation"
    try "mkdir -p $backupLocation"

    # Setup daily backup
    # Commenting out try based error handling as --recurringTask cron value isn't being accepted... for some reason.. yet to figureout
    # try "$binDir/backup  --hostname localhost --port $ldapsPort --bindDN \"$rootUserDN\" --bindPasswordFile \"$passwordFile\"  --backUpAll --backupID \"$storeType-Store-Daily-Full-Backup-Binary\" --recurringTask \"${dailyBackupFrequencyCron}\" --backupDirectory $backupLocation --completionNotify $backupStatusNotificationAddress --errorNotify $backupStatusNotificationAddress --trustAll "
    echo "     o setup daily backup"
    $binDir/backup  --hostname localhost --port $ldapsPort --bindDN "$rootUserDN" --bindPasswordFile "$passwordFile" --backUpAll --backupID "SwissId-${storeType}Store-${env}-Full-Backup-Binary" --backupDirectory $backupLocation --recurringTask "$dailyBackupFrequencyCron" --errorNotify ${backupStatusNotificationAddress} --trustAll

    # Setup incremental backup
    echo "     o setup incremental backup"
    $binDir/backup  --hostname localhost --port $ldapsPort --bindDN "$rootUserDN" --bindPasswordFile "$passwordFile" --backUpAll --backupID "SwissId-${storeType}Store-${env}-Incremental-Backup-Binary" --incremental --recurringTask "${incrementalBackupFrequencyCron}"  --backupDirectory $backupLocation  --errorNotify ${backupStatusNotificationAddress} --trustAll

    configureBackupHouseKeeping

    # reset backup.info files so that the next incremental backup is a full backup without any dependencies on any previous backup files.
    echo "     o reset backup.info files"
    [ -f $backupLocation/userRoot/backup.info ] && mv $backupLocation/userRoot/backup.info $backupLocation/userRoot/backup.info.original
    [ -f $backupLocation/schema/backup.info ] && mv $backupLocation/schema/backup.info $backupLocation/schema/backup.info.original
    [ -f $backupLocation/tasks/backup.info ] && mv $backupLocation/tasks/backup.info $backupLocation/tasks/backup.info.original
}

configureBackupHouseKeeping() {
    echo "     o setup backup housekeeping cronjob"
    chmod 755 ${BATCH_DIR}/opendj/backup-housekeeping.sh
    ( crontab -l | egrep -v "${opendjExtractTargetPath}/backup-housekeeping.sh $backupLocation|${BATCH_DIR}/opendj/backup-housekeeping.sh $backupLocation" ; echo "${backupFilesHouseKeepingCron} ${BATCH_DIR}/opendj/backup-housekeeping.sh $backupLocation $backupFilesPurgeDays") | crontab -
}

configureReplicationStatus() {
    echo "     o setup replication status cronjob"
    chmod 755 ${BATCH_DIR}/opendj/status-replication.sh
    ( crontab -l | grep -v "${BATCH_DIR}/opendj/status-replication.sh $env $server_to_configure" ; echo "00,15,30,45 * * * * ${BATCH_DIR}/opendj/status-replication.sh $env $server_to_configure 2>/dev/null") | crontab -
}

configureLdapStats() {
    echo "     o setup LDAP statistics cronjob"
    chmod 755 ${BATCH_DIR}/opendj/status-ldap.sh
    ( crontab -l | grep -v "${BATCH_DIR}/opendj/status-ldap.sh $env $server_to_configure" ; echo "00,15,30,45 * * * * ${BATCH_DIR}/opendj/status-ldap.sh $env $server_to_configure 2>/dev/null") | crontab -
}
