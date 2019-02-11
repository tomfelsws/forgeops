#!/bin/bash

BATCH_DIR=$(cd $(dirname "$0"); pwd)
source ${BATCH_DIR}/opendj/lib-shared-opendj.sh

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
