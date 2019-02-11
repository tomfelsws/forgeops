#!/bin/bash

##############################################################################
# Setup User Store
##############################################################################

userStoreSetup() {
    echo "*** Setup User Store..."

    if [ "$configureReplication" = "true" -o "$upgradeOpenDJ" = "true" ]; then
        echo "Configuring replication"
        replicateStores
    fi

    # Cronjob to report some LDAP statistics
    configureLdapStats
}
