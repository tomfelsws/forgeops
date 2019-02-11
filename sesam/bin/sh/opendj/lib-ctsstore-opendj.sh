#!/bin/bash

##############################################################################
# Setup CTS Store
##############################################################################

ctsStoreSetup() {
    echo "*** Setup CTS Store..."

    # Execute on primary only (secondary will replicate schema, DIT, ACIs and data)
    if [ "$primaryOrSecondary" = "primary" ]; then

        # Schema
        ctsStoreImportSchema

        # DIT
        ctsStoreImportDit

        # ACIs
        ctsStoreApplyAci

        # Monitoring Users
        importMonitoringAdminUsers
    fi

    # Monitoring
    configureMonitoring

    if [ "$configureReplication" = "true" -o "$upgradeOpenDJ" = "true" ]; then
        # Replication
        replicateStores
    fi

    # Indexes
    # Not replicated and must be created after replication, so that the schema
    # attributes have been replicated
    ctsStoreCreateIndexes
    rebuildIndex

    # Cronjob to report some LDAP statistics
    configureLdapStats
}

##############################################################################
# Replace passwords
##############################################################################

ctsStoreReplacePasswords() {
    echo "     o replace passwords in input files"
    try "sed -e \"s/@ctsStoreApplicationAdminPassword_placeholder@/${ctsStoreApplicationAdminPassword}/\"  \"${CONFIG_DIR}/opendj/ldif/cts-container.ldif\" > $opendjExtractTargetPath/cts-container.ldif "
}

##############################################################################
# Schema
##############################################################################

ctsStoreImportSchema() {
    echo "*** Import schema..."

    echo "     o cts-add-schema.ldif"
    try "$binDir/ldapmodify --hostname localhost --port $ldapsPort --bindDN \"$rootUserDN\" --bindPasswordFile \"$passwordFile\" --filename \"$CONFIG_DIR/opendj/schema/cts/cts-add-schema.ldif\" --useSSL --trustAll "

    echo "     o cts-add-multivalue.ldif"
    try "$binDir/ldapmodify --hostname localhost --port $ldapsPort --bindDN \"$rootUserDN\" --bindPasswordFile \"$passwordFile\" --filename \"$CONFIG_DIR/opendj/schema/cts/cts-add-multivalue.ldif\" --useSSL --trustAll "
}

##############################################################################
# DIT
##############################################################################

ctsStoreImportDit() {
    echo "*** Import directory tree..."
    ctsStoreReplacePasswords
    echo "     o cts-container.ldif"
    try "$binDir/ldapmodify --hostname localhost --port $ldapsPort --bindDN \"$rootUserDN\" --bindPasswordFile \"$passwordFile\" --filename \"$opendjExtractTargetPath/cts-container.ldif\" --useSSL --trustAll "
    rm -rf $opendjExtractTargetPath/cts-container.ldif
}

##############################################################################
# ACI
##############################################################################

ctsStoreApplyAci() {
    echo "*** Apply ACIs..."
    try "$binDir/dsconfig set-access-control-handler-prop --no-prompt --hostname localhost --port $adminConnectorPort --bindDN \"$rootUserDN\" --bindPasswordFile \"$passwordFile\" --add 'global-aci:(target = \"ldap:///cn=schema\")(targetattr = \"attributeTypes || objectClasses\")(version 3.0; acl \"Modify schema\"; allow (write) userdn = \"ldap:///uid=openam_cts,ou=admins,$baseDN\";)' --trustAll -n "
    echo "ACIs applied."
}

##############################################################################
# Indexes
##############################################################################

ctsStoreCreateIndexes() {
    echo "*** Create indexes..."

    echo "     o cts-add-indexes.txt"
    try "$binDir/dsconfig  --hostname localhost --port $adminConnectorPort  --bindDN \"$rootUserDN\"  --bindPasswordFile \"$passwordFile\" --batchFilePath ${CONFIG_DIR}/opendj/index/cts-add-indexes.txt --trustAll  --no-prompt "

    echo "     o cts-add-multivalue-indices.ldif"
    try "$binDir/ldapmodify --hostname localhost --port $ldapsPort --bindDN \"$rootUserDN\" --bindPasswordFile \"$passwordFile\" --filename \"$CONFIG_DIR/opendj/schema/cts/cts-add-multivalue-indices.ldif\" --useSSL --trustAll "

    echo "Indexes created."
}
