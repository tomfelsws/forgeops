#!/bin/bash

try() {
    command_to_execute=$*
    eval ${command_to_execute};
    command_execution_exitcode=$?

    if [ ${command_execution_exitcode} -ne 0 ]; then
        echo "------------------------------------------------------------------------------------------------------"
        echo "Install aborted: command [${command_to_execute}] failed with error code $command_execution_exitcode"
        echo "------------------------------------------------------------------------------------------------------"
        exit 1
    fi
}

# Note: do not put any other code or text inside the below function including any echo ..
# else the evaluation of number of opendj processes inside shutDownOpenDJ function will break
fetchOpenDJProcessId() {
    opendj_process_id=$(ps -fu $USER | grep "${opendjExtractTargetPath}/opendj/config/[c]onfig.ldif" | awk '{print $2}')
    #Note: DO NOT REMOVE THE BELOW ECHO. IT IS REQUIRED AND PART OF THE FUNCTION!!!!
    echo ${opendj_process_id}
}

shutDownOpenDJ() {
    echo "     o shutdown OpenDJ instance..."
    process_id=$(fetchOpenDJProcessId)

    echo "OpenDJ process id is >> "$process_id

    NUMBER_OF_OPENDJ_PROCESSES=$(echo "$process_id" | wc -w)
    echo "NUMBER_OF_OPENDJ_PROCESSES: $NUMBER_OF_OPENDJ_PROCESSES"

    if [[ $NUMBER_OF_OPENDJ_PROCESSES > 1 ]]; then
        echo "Warning!!!! More than one processes for this OpenDJ type running.. will exit..Admin should clean up zombie/unwanted processes and then rerun the script.."
        exit 1
    fi

    if [ $process_id ]; then
        if [[ $process_id > 0 ]]; then
            try "${opendjExtractTargetPath}/opendj/bin/stop-ds"
            echo "OpenDJ shut down executed"
            echo "Waiting for OpenDJ to go down graciously."
            for cnt in $(seq 1 30);
            do
                process_id=$(fetchOpenDJProcessId)
                if [[ $process_id > 0 ]]; then
                    echo -n "."
                    sleep 1
                else
                    break
                fi
            done
        else
            echo "OpenDJ already down..."
        fi
    fi
}

cleanupExistingOpenDJInstallation() {
    echo "     o cleanup existing OpenDJ installation..."

    # Commenting out replication disable as DEPO can't support this.
    # DEPO moves the whole installation folder to a backup location.
    # Tested without replication disable, no regression found.
    # Disable any existing replication..
    # Not using "try" test to avoid script breaking in case replication hasn't been setup on node
    # echo "Attempting to disable any existing replication.."

    # $binDir/dsreplication disable --disableAll --hostname localhost  --port $adminConnectorPort --bindDN "$rootUserDN" --adminPasswordFile "$passwordFile" --trustAll  --no-prompt

    shutDownOpenDJ

    if [ -d $opendjExtractTargetPath ]; then
        rm -rf $opendjExtractTargetPath/opendj
        echo "$opendjExtractTargetPath/opendj deleted"
        #rm -rf $opendjExtractTargetPath/jvm
        #echo "$opendjExtractTargetPath/jvm deleted"
    fi
}

unzipOpenDJ() {
    echo "     o extract OpenDJ installation..."
    try "unzip ${SOFTWARE_DIR}/opendj/DS-${opendjVersion}.zip -d $opendjExtractTargetPath"

    # Create directory to store jvm logs: gc, heap etc.
    # mkdir "$opendjExtractTargetPath/jvm"
}

createPasswordFile() {
    echo "     o create OpenDJ password files"
    passwordFile="${binDir}/.pass"
    [ ! -f $passwordFile ] && echo $directoryAdminPassword > $passwordFile
    chmod 400 ${passwordFile}
}

modifyJVMArgs() {
    echo "*** Modify JVM properties..."
    try "sed -e 's/start-ds.java-args=-server/start-ds.java-args=${OPENDJ_CUSTOM_JVM_ARGS}/' \"${opendjExtractTargetPath}/opendj/config/java.properties\"  > \"${opendjExtractTargetPath}/opendj/config/java.properties.new\" "

    echo "     o modify ${opendjExtractTargetPath}/opendj/config/java.properties..."
    try "mv ${opendjExtractTargetPath}/opendj/config/java.properties.new ${opendjExtractTargetPath}/opendj/config/java.properties "
    # cat ${opendjExtractTargetPath}/opendj/config/java.properties

    echo "     o restart OpenDJ instance..."
    try "shutDownOpenDJ"
    try "${opendjExtractTargetPath}/opendj/bin/start-ds"
}

baseSetup() {
    echo "*** Setup directory server..."
    try "$opendjHome/setup directory-server \
        --rootUserDN \"$rootUserDN\" \
        --rootUserPassword \"$directoryAdminPassword\" \
        --hostname localhost
        --ldapPort \"$ldapPort\" \
        --ldapsPort \"$ldapsPort\" \
        --adminConnectorPort \"$adminConnectorPort\" \
        --baseDN \"$baseDN\" \
        --useJavaKeystore \"$useJavaKeystore\" \
        --keyStorePassword \"$keyStorePassword\" \
        --certNickname \"$certNickname\" \
        --enableStartTLS \
        --acceptLicense
    "
    echo "Base installation complete."

    if [ "$mailserver" ]; then
        echo "*** Setup directory server..."
        try "$binDir/dsconfig --hostname localhost --port $adminConnectorPort --bindDN \"$rootUserDN\" --bindPasswordFile \"$passwordFile\" -n set-global-configuration-prop --set smtp-server:$mailserver  --trustAll --no-prompt "
    fi

    echo "*** Setup combined log format..."
    try "$binDir/dsconfig --hostname localhost --port $adminConnectorPort --bindDN \"$rootUserDN\" --bindPasswordFile \"$passwordFile\" -n set-log-publisher-prop --publisher-name 'File-Based Access Logger' --set log-format:combined --trustAll --no-prompt "

    modifyJVMArgs
}

unzipSupportExtractTool() {
    echo "     o unzip support extract tool"
    rm -rf $opendjExtractTargetPath/opendj-support-extract-tool
    try "unzip ${SOFTWARE_DIR}/opendj/opendj-support-extract-tool.zip -d $opendjExtractTargetPath"
}

disableLdapPort() {
    echo "     o disable ldap port"
    try "$binDir/dsconfig set-connection-handler-prop --hostname localhost --port $adminConnectorPort --bindDN \"$rootUserDN\" --bindPasswordFile \"$passwordFile\" --handler-name \"LDAP Connection Handler\" --set enabled:false --trustAll --no-prompt "
}


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

exportServerCert() {
    echo "     o export server certificate"
    $JAVA_HOME_BIN/keytool  -export  -alias server-cert  -file  $opendjExtractTargetPath/opendj-$storeType-$adminConnectorPort-$HOSTNAME.crt  -keystore $opendjHome/config/keystore -storepass $(cat $opendjHome/config/keystore.pin)
}

rebuildIndex() {
    echo "     o rebuild index"
    try "$binDir/rebuild-index  --hostname localhost --port $adminConnectorPort  --bindDN \"$rootUserDN\" --bindPasswordFile \"$passwordFile\" --baseDN \"$baseDN\"  --rebuildAll  --start 0 --trustAll "
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

importMonitoringAdminUsers() {
    echo "*** Import monitoring admin users"
    try "sed -e \"s/@opendjjmxmonitoringuserPassword_placeholder@/${opendjJMXMonitoringAdminPassword}/\" \"${CONFIG_DIR}/opendj/ldif/add-opendj-monitoring-admin-entries.ldif\" > $opendjExtractTargetPath/add-opendj-monitoring-admin-entries.ldif"
    try "$binDir/ldapmodify --continueOnError --hostname localhost --port $ldapsPort --bindDN \"$rootUserDN\" --bindPasswordFile \"$passwordFile\" --filename $opendjExtractTargetPath/add-opendj-monitoring-admin-entries.ldif  --useSSL --trustAll "
    rm -rf $opendjExtractTargetPath/add-opendj-monitoring-admin-entries.ldif
}

configureMonitoring() {
    echo "*** Configure monitoring"
    # try "$binDir/dsconfig set-connection-handler-prop  --hostname localhost --port $adminConnectorPort --bindDN \"$rootUserDN\" --bindPasswordFile \"$passwordFile\" --handler-name \"JMX Connection Handler\" --set enabled:true --set use-ssl:true --set key-manager-provider:\"cn=JKS,cn=Key Manager Providers,cn=config\" --set ssl-cert-nickname:server-cert --trustAll -n "
    # $binDir/dsconfig set-connection-handler-prop  --hostname localhost --port $adminConnectorPort --bindDN  "$rootUserDN" --bindPasswordFile "$passwordFile" --handler-name "JMX Connection Handler" --set enabled:true --set rmi-port:$jmxRMIPort --set use-ssl:true --set key-manager-provider:JKS --set ssl-cert-nickname:server-cert --trustAll -n
    echo "     o create JMX Connection Handler"
    $binDir/dsconfig create-connection-handler --hostname localhost --port $adminConnectorPort --bindDN  "$rootUserDN" --bindPasswordFile "$passwordFile" --handler-name "JMX Connection Handler" --type jmx --set enabled:true --set listen-port:$jmxPort --set rmi-port:$jmxRMIPort --set use-ssl:true --set key-manager-provider:"Default Key Manager" --set ssl-cert-nickname:server-cert --trustAll --no-prompt
}
