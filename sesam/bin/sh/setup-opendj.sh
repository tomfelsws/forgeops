#!/bin/bash

BATCH_DIR=$(cd $(dirname "$0"); pwd)
source ${BATCH_DIR}/opendj/lib-shared-opendj.sh

##############################################################################
# All Stores
##############################################################################

configureLdapStats
configureReplicationStatus

if [ "$configureBackup" = "true" ]; then
    configureBackup
fi
