#!/bin/bash

##############################################################################
# Setup CTS Store
##############################################################################

ctsStoreSetup() {
    echo "*** Setup CTS Store..."

    if [ "$configureReplication" = "true" -o "$upgradeOpenDJ" = "true" ]; then
        echo "Configuring replication"
        replicateStores
    fi

    # Cronjob to report some LDAP statistics
    configureLdapStats
}
