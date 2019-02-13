#!/bin/bash

##############################################################################
# Post OpenAM installation changes
##############################################################################

configStorePostOpenam() {
    echo "*** Apply Post OpenAM installation changes..."

    echo "     o update self write attributes"
    try "$binDir/ldapmodify --hostname localhost --port $ldapsPort --bindDN \"$rootUserDN\" --bindPasswordFile \"$passwordFile\" --filename ${CONFIG_DIR}/opendj/ldif/update-self-write-attributes.ldif $USE_SSL --trustAll "
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
