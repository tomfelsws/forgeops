#!/bin/bash

##############################################################################
# Setup Config Store
##############################################################################

# embedded configstore does not use SSL
# $CONFIG_SSL is set only in OpenAM env.properties, not in OpenDJ env.properties
if [ -z "$CONFIG_SSL" -o "$CONFIG_SSL" = "SSL" ]; then
  USE_SSL="--useSSL"
else
  USE_SSL=""
fi

configStoreSetup() {
    echo "*** Setup Config Store..."

    # Execute on primary only (secondary will replicate schema, DIT, ACIs and data)
    if [ "$primaryOrSecondary" = "primary"  ]; then

        # Schema
        configStoreImportSchema

        # DIT
        configStoreImportDit

        # ACIs
        configStoreApplyAci

        # Monitoring Users
        importMonitoringAdminUsers

    fi

    configureMonitoring

    if [ "$configureReplication" = "true" -o "$upgradeOpenDJ" = "true" ]; then
        echo "Configuring replication"
        replicateStores
    fi

    # Indexes
    # Not replicated and must be created after replication, so that the schema
    # attributes have been replicated
    configStoreCreateIndexes
    rebuildIndex

    # Cronjob to report some LDAP statistics
    configureLdapStats

}

##############################################################################
# Post OpenAM installation changes
##############################################################################

configStorePostOpenam() {
    echo "*** Apply Post OpenAM installation changes..."

    echo "     o update self write attributes"
    try "$binDir/ldapmodify --hostname localhost --port $ldapsPort --bindDN \"$rootUserDN\" --bindPasswordFile \"$passwordFile\" --filename ${CONFIG_DIR}/opendj/ldif/update-self-write-attributes.ldif $USE_SSL --trustAll "
}

##############################################################################
# Replace passwords
##############################################################################

configStoreReplacePasswords() {
    echo "     o replace passwords in input files"
    try "sed -e \"s/@configStoreApplicationAdminPassword_placeholder@/${configStoreApplicationAdminPassword}/\"  \"${CONFIG_DIR}/opendj/ldif/add-openam-configstore-entries.ldif\" > $opendjExtractTargetPath/add-openam-configstore-entries.ldif "
}

##############################################################################
# Schema
##############################################################################

configStoreImportSchema() {
    echo "*** Import schema..."

    echo "     o opendj_config_schema.ldif"
    try "$binDir/ldapmodify --hostname localhost --port $ldapsPort --bindDN \"$rootUserDN\" --bindPasswordFile \"$passwordFile\" --filename ${CONFIG_DIR}/opendj/schema/opendj_config_schema.ldif $USE_SSL --trustAll"

    echo "     o opendj_user_schema.ldif"
    try "$binDir/ldapmodify --hostname localhost --port $ldapsPort --bindDN \"$rootUserDN\" --bindPasswordFile \"$passwordFile\" --filename ${CONFIG_DIR}/opendj/schema/opendj_user_schema.ldif $USE_SSL --trustAll"
}

##############################################################################
# DIT
##############################################################################

configStoreImportDit() {
    echo "*** Import directory tree..."
    configStoreReplacePasswords
    echo "     o add-openam-configstore-entries.ldif"
    try "$binDir/ldapmodify --hostname localhost --port $ldapsPort --bindDN \"$rootUserDN\" --bindPasswordFile \"$passwordFile\" --filename \"$opendjExtractTargetPath/add-openam-configstore-entries.ldif\" $USE_SSL --trustAll"
    rm -rf $opendjExtractTargetPath/add-openam-configstore-entries.ldif
}

##############################################################################
# ACI
##############################################################################

configStoreApplyAci() {
    echo "*** Apply ACIs..."
    try "$binDir/dsconfig set-access-control-handler-prop --add global-aci:'(target = \"ldap:///cn=schema\")(targetattr = \"attributeTypes || objectClasses\")(version 3.0; acl \"Modify schema\"; allow (write) (userdn=\"ldap:///uid=openam,ou=admins,$baseDN\");)' --hostname localhost --port $adminConnectorPort --bindDN \"$rootUserDN\" --bindPasswordFile \"$passwordFile\" --trustAll  -n "
    echo "ACIs applied."
}

##############################################################################
# Indices
##############################################################################

configStoreCreateIndexes() {
    echo "*** Create indexes..."

    echo "     o sunxmlkeyvalue"
    try "$binDir/dsconfig create-backend-index --hostname localhost --port $adminConnectorPort --bindDN \"$rootUserDN\" --bindPasswordFile \"$passwordFile\" --backend-name userRoot --index-name sunxmlkeyvalue --set index-type:equality --set index-type:substring --trustAll --no-prompt "

    echo "     o iplanet-am-user-federation-info-key"
    try "$binDir/dsconfig create-backend-index --hostname localhost --port $adminConnectorPort --bindDN \"$rootUserDN\" --bindPasswordFile \"$passwordFile\" --backend-name userRoot --index-name iplanet-am-user-federation-info-key --set index-type:equality  --trustAll --no-prompt "

    echo "     o sun-fm-saml2-nameid-infokey"
    try "$binDir/dsconfig create-backend-index --hostname localhost --port $adminConnectorPort --bindDN \"$rootUserDN\" --bindPasswordFile \"$passwordFile\" --backend-name userRoot --index-name sun-fm-saml2-nameid-infokey --set index-type:equality --trustAll --no-prompt "
    echo "Indexes created"
}

importRelyingParties() {
    echo "*** Importing relying parties ..."

    local relyingParties="$backupLocation/relyingParties.ldif"

    try "touch ${relyingParties}"

    echo "     o Exporting relying parties from $primaryOpenDJNodeHost to $relyingParties"
    try "$binDir/ldapsearch -X -Z -h ${primaryOpenDJNodeHost} -p ${primaryOpenDJNodeAdminPort} -D \"${rootUserDN}\" -j \"${passwordFile}\" -b 'ou=default,ou=OrganizationConfig,ou=1.0,ou=AgentService,ou=services,o=sesam,ou=services,dc=swisssign,dc=com' -s sub \"(objectClass=*)\" \*  > ${relyingParties}"

    echo "     o Importing relying parties from $relyingParties into $secondaryOpenDJNodeHost"
    try "$binDir/ldapmodify -c -X -Z -h localhost  -p ${primaryOpenDJNodeAdminPort} -D \"${rootUserDN}\" -j \"${passwordFile}\" ${relyingParties}"
}
