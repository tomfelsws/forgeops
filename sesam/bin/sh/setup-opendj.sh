#!/bin/bash

##############################################################################
# Set global variables
##############################################################################

BATCH_DIR=$(cd $(dirname "$0"); pwd)
source ${BATCH_DIR}/opendj/lib-jdk.sh
source ${BATCH_DIR}/opendj/lib-header-opendj.sh
source ${BATCH_DIR}/opendj/lib-shared-opendj.sh

##############################################################################
# Start
##############################################################################

echo "*************************************************************************"
echo "***"
echo "***   Setup OpenDJ $opendjVersion"
echo "***"
echo "***   Store Type: $storeType"
echo "***"
echo "***   Deployment is started (`date`)"
echo "*************************************************************************"
echo ""

##############################################################################
# Base Setup
##############################################################################

jdk_init

if [ "$installOpenDJ" = "true" ]; then
    echo "*** Start base installation..."
    cleanupExistingOpenDJInstallation
    unzipOpenDJ
    deploy_jdk
    createPasswordFile
    baseSetup
    unzipSupportExtractTool

    if [ "$generateSelfSignedCertificate" = "true" ]; then
        exportServerCert
    fi

    if [ "$turnOffLdapPort" = "true" ]; then
        disableLdapPort
    fi

fi

##############################################################################
# Config Store
##############################################################################

if [ "$storeType" = "config" ]; then
    source ${BATCH_DIR}/opendj/lib-configstore-opendj.sh
    configStoreSetup
fi

##############################################################################
# User Store
##############################################################################

if [ "$storeType" = "user" ]; then
    source ${BATCH_DIR}/opendj/lib-userstore-opendj.sh
    userStoreSetup
fi

##############################################################################
# Token (CTS) Store
##############################################################################

if [ "$storeType" = "cts" ]; then
    source ${BATCH_DIR}/opendj/lib-ctsstore-opendj.sh
    ctsStoreSetup
fi

##############################################################################
# All Stores
##############################################################################

configureReplicationStatus

if [ "$configureBackup" = "true" ]; then
    configureBackup
fi

echo "*************************************************************************"
echo "***"
echo "*** Deployment is finished (`date`)"
echo "***"
echo "*************************************************************************"
