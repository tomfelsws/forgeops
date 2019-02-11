#!/bin/bash

# Point to point replication between OpenDJ nodes
replicateStores() {
    echo "*** Start replication..."
    echo "     o enable replication"
    if [ "$noSchemaReplication" = "true" ]; then
        echo "noSchemaReplication: true"
        try "$binDir/dsreplication configure --noSchemaReplication --adminUID admin --adminPasswordFile \"$passwordFile\" --baseDN \"$baseDN\" --host1 $primaryOpenDJNodeHost --port1 $primaryOpenDJNodeAdminPort  --bindDN1  \"$rootUserDN\" --bindPasswordFile1 \"$passwordFile\" --replicationPort1 $primaryOpenDJNodeReplicationPort --secureReplication1 --host2   $secondaryOpenDJNodeHost  --port2 $secondaryOpenDJNodeAdminPort --bindDN2 \"$rootUserDN\" --bindPasswordFile2 \"$passwordFile\" --replicationPort2 $secondaryOpenDJNodeReplicationPort  --secureReplication2  --trustAll  --no-prompt "
    else
        echo "noSchemaReplication: false (default)"
        try "$binDir/dsreplication configure --adminUID admin --adminPasswordFile \"$passwordFile\" --baseDN \"$baseDN\" --host1 $primaryOpenDJNodeHost --port1 $primaryOpenDJNodeAdminPort  --bindDN1  \"$rootUserDN\" --bindPasswordFile1 \"$passwordFile\" --replicationPort1 $primaryOpenDJNodeReplicationPort --secureReplication1 --host2   $secondaryOpenDJNodeHost  --port2 $secondaryOpenDJNodeAdminPort --bindDN2 \"$rootUserDN\" --bindPasswordFile2 \"$passwordFile\" --replicationPort2 $secondaryOpenDJNodeReplicationPort  --secureReplication2  --trustAll  --no-prompt "
    fi

    # Initialize replication providing hostname of primary node
    # try "$binDir/dsreplication initialize-all  --adminUID admin --adminPasswordFile \"$passwordFile\" --baseDN \"$baseDN\" --hostname $primaryOpenDJNodeHost --port $primaryOpenDJNodeAdminPort --trustAll --no-prompt"
    # Using initialize instead of initialize-all to prevent data initialization on other servers in the topology (in future)
    echo "     o initialize replication"
    try "$binDir/dsreplication initialize  --adminUID admin --adminPasswordFile \"$passwordFile\" --baseDN \"$baseDN\" --hostSource $primaryOpenDJNodeHost --portSource $primaryOpenDJNodeAdminPort --hostDestination $secondaryOpenDJNodeHost --portDestination $secondaryOpenDJNodeAdminPort --trustAll --no-prompt"

    echo "     o printing replication status"
    $binDir/dsreplication status --adminUID admin --adminPasswordFile "$passwordFile" --hostname localhost --port $adminConnectorPort --trustAll --no-prompt

    # enable cmdline scripts to enable & disable replication during upgrades
    chmod 755 ${BATCH_DIR}/opendj/enable-replication.sh
    chmod 755 ${BATCH_DIR}/opendj/disable-replication.sh

    echo "Point to point store replication configured and initialized!"

    if [ "$storeType" = "user" -o "$storeType" = "cts" ]; then
        echo ".........Now configuring changelog for delete and edit operations...................."
        configureChangeLog
    fi
}

configureChangeLog() {
    echo "*** Configure change log..."

    if [ \( "$primaryOrSecondary" = "primary" -a "$upgradeOpenDJ" = "true" \) -o \( "$primaryOrSecondary" = "secondary" \) ]; then
        # we are either on the secondary server or we have an upgrade and are on the primary server
        # for the latter case, $primaryOpenDJNodeHost is now pointing to the second instance that may be running an old version of OpenDJ
        # hence we cannot update the second instance changelog at this point as this would result in an error message about incompatible OpenDJ versions:
        #   "The OpenDJ binary version -3.5.1.23b322a7502f029b6d3725212c162de36f038122- does not match the installed version -4.0.0.0b7da454b79944f54e66daf3f591cefb5d77165b-."
        #   "Please run upgrade before continuing"
        if [ "$primaryOrSecondary" = "primary" ]; then
            echo "     o primary server during upgrade -> updating replication properties on $secondaryOpenDJNodeHost"
        else
            echo "     o secondary server -> updating replication properties on $secondaryOpenDJNodeHost"
        fi
        try "$binDir/dsconfig set-external-changelog-domain-prop --hostname $secondaryOpenDJNodeHost --port $secondaryOpenDJNodeAdminPort --bindDN \"$rootUserDN\" --bindPasswordFile \"$passwordFile\" --provider-name \"Multimaster Synchronization\" --domain-name $baseDN  --add ecl-include-for-deletes:"*" --add ecl-include-for-deletes:"+"   --trustAll  -n "
        try "$binDir/dsconfig set-external-changelog-domain-prop --hostname $secondaryOpenDJNodeHost --port $secondaryOpenDJNodeAdminPort --bindDN \"$rootUserDN\" --bindPasswordFile \"$passwordFile\" --provider-name \"Multimaster Synchronization\" --domain-name $baseDN  --add ecl-include:"*" --add ecl-include:"+"    --trustAll  -n "
        try "$binDir/dsconfig set-replication-server-prop --hostname $secondaryOpenDJNodeHost --port $secondaryOpenDJNodeAdminPort --bindDN \"$rootUserDN\" --bindPasswordFile \"$passwordFile\" --provider-name \"Multimaster Synchronization\" --set replication-purge-delay:$replicationPurgeDelay   --trustAll  -n "
    else
        # we are on the primary server but no upgrade mode
        # therefore there is no replication set up yet and no replication attributes have to be set anywhere
        # this is equivalent to a new install on the primary with no data to be replicated
        echo "     o primary server with no upgrade -> no replication properties to be updated on $primaryOpenDJNodeHost"
    fi

    if [ "$primaryOrSecondary" = "secondary" ]; then
        # we are on the secondary server and must also update the primary server properties as
        # the properties of the secondary server (i.e. ourself) have already been update above
        echo "     o secondary server -> updating replication properties on $primaryOpenDJNodeHost"
        try "$binDir/dsconfig set-external-changelog-domain-prop --hostname $primaryOpenDJNodeHost --port $primaryOpenDJNodeAdminPort --bindDN \"$rootUserDN\" --bindPasswordFile \"$passwordFile\" --provider-name \"Multimaster Synchronization\" --domain-name $baseDN  --add ecl-include-for-deletes:"*" --add ecl-include-for-deletes:"+"   --trustAll  -n "
        try "$binDir/dsconfig set-external-changelog-domain-prop --hostname $primaryOpenDJNodeHost --port $primaryOpenDJNodeAdminPort --bindDN \"$rootUserDN\" --bindPasswordFile \"$passwordFile\" --provider-name \"Multimaster Synchronization\" --domain-name $baseDN  --add ecl-include:"*" --add ecl-include:"+"    --trustAll  -n "
        try "$binDir/dsconfig set-replication-server-prop --hostname $primaryOpenDJNodeHost --port $primaryOpenDJNodeAdminPort --bindDN \"$rootUserDN\" --bindPasswordFile \"$passwordFile\" --provider-name \"Multimaster Synchronization\" --set replication-purge-delay:$replicationPurgeDelay   --trustAll  -n "
    fi
}

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
