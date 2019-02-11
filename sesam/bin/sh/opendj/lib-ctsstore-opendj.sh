#!/bin/bash

##############################################################################
# Setup CTS Store
##############################################################################

ctsStoreSetup() {
    echo "*** Setup CTS Store..."

    # Execute on primary only (secondary will replicate schema, DIT, ACIs and data)
    if [ "$primaryOrSecondary" = "primary" ]; then
        importMonitoringAdminUsers
    fi

    if [ "$configureReplication" = "true" -o "$upgradeOpenDJ" = "true" ]; then
        echo "Configuring replication"
        replicateStores
    fi

    # Cronjob to report some LDAP statistics
    configureLdapStats
}
