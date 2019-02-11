#!/bin/bash

##############################################################################
# Setup User Store
##############################################################################
userStoreSetup() {
    echo "*** Setup User Store..."

    # $CONFIG_TYPE is usually set in OpenAM env.properties
    # if this function is called for an embedded userstore from setup-openam.sh, it is set to "embedded"
    # if this function is called for a normal userstore, it is not set at all and hence we give it a value
    [ -z "$CONFIG_TYPE" ] && CONFIG_TYPE=userstore
    [ "$CONFIG_TYPE" = "embedded" ] && echo "*** This is an embedded userstore..."

    # embedded userstore does not use SSL
    # $CONFIG_SSL is set only in OpenAM env.properties, not in OpenDJ env.properties
    if [ -z "$CONFIG_SSL" -o "$CONFIG_SSL" = "SSL" ]; then
      USE_SSL="--useSSL"
    else
      USE_SSL=""
    fi

    # First, replicate all data from secondary instance
    if [ "$configureReplication" = "true" -o "$upgradeOpenDJ" = "true" ]; then
        # Replication
        replicateStores
    fi

    # Execute on primary only (secondary will replicate schema, DIT, ACIs and data)
    if [ "$primaryOrSecondary" = "primary" ]; then

        # Schema
        [ "$CONFIG_TYPE" != "embedded" ] && userStoreImportSchema
        userStoreImportSwissIDSchema

        # DIT
        userStoreImportDit

        # ACIs
        userStoreApplyAci

        # Password Policy
        userStoreUpdatePasswordPolicy

        # Uniqueness (make sure it is applied before data is loaded)
        userStoreApplyUniqueness

        # Monitoring Users
        [ "$CONFIG_TYPE" != "embedded" ] && importMonitoringAdminUsers

    fi

    if [ "$primaryOrSecondary" = "secondary" ]; then
        # Uniqueness
        userStoreApplyUniqueness
    fi

    # Monitoring
    [ "$CONFIG_TYPE" != "embedded" ] && configureMonitoring

    # load groups and users after replication so we include any changes during an upgradeOpenDJ
    # This may result in error messages about duplicates which is ok during an upgrade
    if [ "$primaryOrSecondary" = "primary" ]; then
        # Users and groups
        userStoreSetupUsersAndGroups
    fi

    if [ "$CONFIG_TYPE" != "embedded" ]; then
        # Indexes
        # Not replicated and must be created after replication, so that the schema
        # attributes have been replicated
        userStoreCreateIndexes
        rebuildIndex

        # Cronjob to report some LDAP statistics
        configureLdapStats
    fi

    # CleanUp
    cleanUp
}

##############################################################################
# Post OpenAM installation changes
##############################################################################

userStorePostOpenam() {
    echo "*** Apply Post OpenAM installation changes..."

    # Commented as attempting to create indices as part of userStoreSetup()
    # userStoreCreateIndexes
    # rebuildIndex
}

##############################################################################
# Replace passwords
##############################################################################

userStoreReplacePasswordsInScripts() {
    echo "     o replace passwords in script files"
    try "sed -e \"s/@userStoreApplicationAdminPassword_placeholder@/${userStoreApplicationAdminPassword}/\"  \"${CONFIG_DIR}/opendj/ldif/add-openam-userstore-entries.ldif\" > $opendjExtractTargetPath/add-openam-userstore-entries.ldif"
    try "sed -e \"s/@supportApplicationAdminPassword_placeholder@/${supportApplicationAdminPassword}/\" -e \"s/@idcheckApplicationAdminPassword_placeholder@/${idcheckApplicationAdminPassword}/\" -e \"s/@selfmanagementApplicationAdminPassword_placeholder@/${selfmanagementApplicationAdminPassword}/\"  \"${CONFIG_DIR}/opendj/ldif/add-custom-applications-userstore-entries.ldif\" > $opendjExtractTargetPath/add-custom-applications-userstore-entries.ldif"
    try "sed -e \"s/@accountManagerUserPassword_placeholder@/${accountManagerUserPassword}/\"  \"${CONFIG_DIR}/opendj/ldif/openam-accountmanager-user.ldif\" > $opendjExtractTargetPath/openam-accountmanager-user.ldif"
}

userStoreReplacePasswordsInOpenDJBackupScripts() {
    echo "     o replace passwords in OpenDJ backup script files"
    try "sed -e \"s/@opendjBackupRestoreAdminPassword_placeholder@/${opendjBackupRestoreAdminPassword}/\"  \"${CONFIG_DIR}/opendj/ldif/add-opendj-backup-admin-entries.ldif\" > $opendjExtractTargetPath/add-opendj-backup-admin-entries.ldif"
}

##############################################################################
# Schema
##############################################################################

userStoreImportSchema() {

    # OpenAM schema
    echo "*** Import OpenAM schema..."

    echo "     o opendj_user_schema.ldif"
    try "$binDir/ldapmodify --hostname localhost --port $ldapsPort --bindDN \"$rootUserDN\" --bindPasswordFile \"$passwordFile\" --filename ${CONFIG_DIR}/opendj/schema/opendj_user_schema.ldif $USE_SSL --trustAll"

    echo "     o opendj_dashboard.ldif"
    try "$binDir/ldapmodify --hostname localhost --port $ldapsPort --bindDN \"$rootUserDN\" --bindPasswordFile \"$passwordFile\" --filename ${CONFIG_DIR}/opendj/schema/opendj_dashboard.ldif $USE_SSL --trustAll"

    echo "     o opendj_deviceprint.ldif"
    try "$binDir/ldapmodify --hostname localhost --port $ldapsPort --bindDN \"$rootUserDN\" --bindPasswordFile \"$passwordFile\" --filename ${CONFIG_DIR}/opendj/schema/opendj_deviceprint.ldif $USE_SSL --trustAll"

    echo "     o opendj_kba.ldif"
    echo "trying opendj_kba.ldif schema changes ..."
    try "$binDir/ldapmodify --hostname localhost --port $ldapsPort --bindDN \"$rootUserDN\" --bindPasswordFile \"$passwordFile\" --filename ${CONFIG_DIR}/opendj/schema/opendj_kba.ldif $USE_SSL --trustAll"

    echo "     o opendj_oathdevices.ldif"
    echo "trying opendj_oathdevices.ldif schema changes ..."
    try "$binDir/ldapmodify --hostname localhost --port $ldapsPort --bindDN \"$rootUserDN\" --bindPasswordFile \"$passwordFile\" --filename ${CONFIG_DIR}/opendj/schema/opendj_oathdevices.ldif $USE_SSL --trustAll"

    echo "     o opendj_pushdevices.ldif"
    echo "trying opendj_pushdevices.ldif schema changes ..."
    try "$binDir/ldapmodify --hostname localhost --port $ldapsPort --bindDN \"$rootUserDN\" --bindPasswordFile \"$passwordFile\" --filename ${CONFIG_DIR}/opendj/schema/opendj_pushdevices.ldif $USE_SSL --trustAll"
}

userStoreImportSwissIDSchema() {
    # Custom SwissSign schema
    echo "*** Import Custom SwissID schema..."

    echo "     o 99-userIdentity.ldif"
    try "$binDir/ldapmodify --hostname localhost --port $ldapsPort --bindDN \"$rootUserDN\" --bindPasswordFile \"$passwordFile\" --filename ${CONFIG_DIR}/opendj/schema/99-userIdentity.ldif $USE_SSL --trustAll"
}

##############################################################################
# DIT
##############################################################################

userStoreImportDit() {
    echo "*** Import directory tree..."

    userStoreReplacePasswordsInScripts
    userStoreReplacePasswordsInOpenDJBackupScripts

    # Setup user account for OpenAM to connect to OpenDJ user store
    # continue on error as this already exists in an embedded store
    echo "     o add-openam-userstore-entries.ldif"
    try "$binDir/ldapmodify --continueOnError --hostname localhost --port $ldapsPort --bindDN \"$rootUserDN\" --bindPasswordFile \"$passwordFile\" --filename $opendjExtractTargetPath/add-openam-userstore-entries.ldif $USE_SSL --trustAll"

    # Setup user accounts and roles for operations
    # continue on error as this already exists in an embedded store
    echo "     o dit.ldif"
    try "$binDir/ldapmodify --continueOnError --hostname localhost --port $ldapsPort --bindDN \"$rootUserDN\" --bindPasswordFile \"$passwordFile\" --filename \"${CONFIG_DIR}/opendj/ldif/dit.ldif\" $USE_SSL --trustAll"

    # Setup SESAM containers
    echo "     o dit-sesam.ldif"
    try "$binDir/ldapmodify --continueOnError --hostname localhost --port $ldapsPort --bindDN  \"$rootUserDN\" --bindPasswordFile \"$passwordFile\" --filename \"${CONFIG_DIR}/opendj/ldif/dit-sesam.ldif\" $USE_SSL --trustAll"

    # Setup social containers
    echo "     o dit-social.ldif"
    try "$binDir/ldapmodify --continueOnError --hostname localhost --port $ldapsPort --bindDN  \"$rootUserDN\" --bindPasswordFile \"$passwordFile\" --filename \"${CONFIG_DIR}/opendj/ldif/dit-social.ldif\" $USE_SSL --trustAll"

    # Setup user account for Application to connect to OpenDJ user store
    # continue on error as this will produce an expected error for external userstore
    echo "     o add-custom-applications-userstore-entries.ldif"
    try "$binDir/ldapmodify --continueOnError --hostname localhost --port $ldapsPort --bindDN \"$rootUserDN\" --bindPasswordFile \"$passwordFile\" --filename $opendjExtractTargetPath/add-custom-applications-userstore-entries.ldif $USE_SSL --trustAll"

    #Setup user with backup/restore privileges
    echo "     o add-opendj-backup-admin-entries.ldif"
    try "$binDir/ldapmodify --continueOnError --hostname localhost --port $ldapsPort --bindDN \"$rootUserDN\" --bindPasswordFile \"$passwordFile\" --filename $opendjExtractTargetPath/add-opendj-backup-admin-entries.ldif $USE_SSL --trustAll"
}

##############################################################################
# ACI
##############################################################################

userStoreApplyAci() {
    echo "*** Apply ACIs..."
    try "$binDir/dsconfig set-access-control-handler-prop --hostname localhost --port $adminConnectorPort --bindDN \"$rootUserDN\" --bindPasswordFile \"$passwordFile\" --add 'global-aci:(target=\"ldap:///cn=schema\")(targetattr=\"attributeTypes||objectClasses\")(version 3.0; acl \"Modify schema\"; allow (write) userdn=\"ldap:///uid=openam,ou=admins,$baseDN\";)'  --trustAll  -n "
    echo "ACIs applied."
}

##############################################################################
# Users and Groups
#############################################################################

userStoreSetupUsersAndGroups() {
    echo "*** Setup Users and groups..."

    echo "     o support groups"
    try "$binDir/ldapmodify --continueOnError --hostname localhost --port $ldapsPort --bindDN \"$rootUserDN\" --bindPasswordFile \"$passwordFile\" --filename \"${CONFIG_DIR}/opendj/ldif/support-groups.ldif\" $USE_SSL --trustAll "

    echo "     o OpenAM Admin groups"
    try "$binDir/ldapmodify --continueOnError --hostname localhost --port $ldapsPort --bindDN \"$rootUserDN\" --bindPasswordFile \"$passwordFile\" --filename \"${CONFIG_DIR}/opendj/ldif/openam-admin-groups.ldif\" $USE_SSL --trustAll "

    echo "     o technical users"
    try "$binDir/ldapmodify --continueOnError --hostname localhost --port $ldapsPort --bindDN \"$rootUserDN\" --bindPasswordFile \"$passwordFile\" --filename \"$opendjExtractTargetPath/openam-accountmanager-user.ldif\" $USE_SSL --trustAll "

    if [ "$loadOpenAmAdminUsers" = "true" ]; then
        echo "     o OpenAM Admin users"
        try "$binDir/ldapmodify --continueOnError --hostname localhost --port $ldapsPort --bindDN \"$rootUserDN\" --bindPasswordFile \"$passwordFile\" --filename \"${CONFIG_DIR}/opendj/ldif/openam-admin-users.ldif\" $USE_SSL --trustAll "
    fi

    if [ "$loadDemoSupportUsers" = "true" ]; then
        echo "     o support users"
        try "$binDir/ldapmodify --continueOnError --hostname localhost --port $ldapsPort --bindDN \"$rootUserDN\" --bindPasswordFile \"$passwordFile\" --filename \"${CONFIG_DIR}/opendj/ldif/support-users.ldif\" $USE_SSL --trustAll "
    fi

    if [ "$loadDemoUsers" = "true" ]; then
        echo "     o demo users"
        try "$binDir/ldapmodify --continueOnError --hostname localhost --port $ldapsPort --bindDN \"$rootUserDN\" --bindPasswordFile \"$passwordFile\" --filename \"${CONFIG_DIR}/opendj/ldif/test-user.ldif\" $USE_SSL --trustAll "
    fi

    if [ "$loadDemoSuisseIdIdentities" = "true" ]; then
        echo "     o SuisseID identities"
        try "$binDir/ldapmodify --continueOnError --hostname localhost --port $ldapsPort --bindDN \"$rootUserDN\" --bindPasswordFile \"$passwordFile\" --filename \"${CONFIG_DIR}/opendj/ldif/suisseid-identity.ldif\" $USE_SSL --trustAll "
    fi
}

##############################################################################
# Indexes
##############################################################################

userStoreCreateIndexes() {
    echo "*** Create indexes..."

    echo "     o OpenAM indexes"
    try "$binDir/dsconfig create-backend-index --hostname localhost --port $adminConnectorPort --bindDN \"$rootUserDN\" --bindPasswordFile \"$passwordFile\" --backend-name userRoot --index-name iplanet-am-user-federation-info-key --set index-type:equality --trustAll --no-prompt"
    try "$binDir/dsconfig create-backend-index --hostname localhost --port $adminConnectorPort --bindDN \"$rootUserDN\" --bindPasswordFile \"$passwordFile\" --backend-name userRoot --index-name sun-fm-saml2-nameid-infokey --set index-type:equality --trustAll --no-prompt "

    echo "     o SwissId custom indexes"
    try "$binDir/dsconfig  --hostname localhost --port $adminConnectorPort  --bindDN \"$rootUserDN\" --bindPasswordFile \"$passwordFile\" --batchFilePath ${CONFIG_DIR}/opendj/index/swissid-userstore-add-indexes.txt  --trustAll  --no-prompt "

    echo "Indexes created"
}

##############################################################################
# Password Policy
##############################################################################

userStoreUpdatePasswordPolicy() {
    echo "     o update Password Policy"
    try "$binDir/dsconfig --hostname localhost --port $adminConnectorPort --bindDN \"$rootUserDN\" --bindPasswordFile \"$passwordFile\" -n set-password-policy-prop --policy-name \"Default Password Policy\" --set \"default-password-storage-scheme:Salted SHA-256\" --trustAll --no-prompt "
}

##############################################################################
# Uniqueness
##############################################################################

userStoreApplyUniqueness() {
    echo "*** Apply uniqueness attributes..."

    echo "     o enable UID unique Attribute"
    try "$binDir/dsconfig --hostname localhost --port $adminConnectorPort --bindDN \"$rootUserDN\" --bindPasswordFile \"$passwordFile\" set-plugin-prop --plugin-name \"UID Unique Attribute\" --set base-dn:ou=people,$baseDN --set enabled:true  --trustAll --no-prompt "

    echo "     o create Email unique Attribute"
    try "$binDir/dsconfig --hostname localhost --port $adminConnectorPort --bindDN \"$rootUserDN\" --bindPasswordFile \"$passwordFile\" create-plugin --plugin-name \"Email Unique Attribute\" --type unique-attribute  --set type:mail --set base-dn:ou=people,$baseDN --set enabled:true  --trustAll --no-prompt "
}

##############################################################################
# CleanUp
##############################################################################

cleanUp() {
    echo "*** Cleanup setup configuration..."

    echo "     o delete temporary ldif files from $opendjExtractTargetPath"
    rm -rf $opendjExtractTargetPath/add-openam-userstore-entries.ldif
    rm -rf $opendjExtractTargetPath/add-custom-applications-userstore-entries.ldif
    rm -rf $opendjExtractTargetPath/add-opendj-backup-admin-entries.ldif
    rm -rf $opendjExtractTargetPath/openam-accountmanager-user.ldif
}
