#!/usr/bin/env bash

CTS_PW=$( cat $SECRET_PATH/cts.pw )
USERSTORE_PW=$( cat $SECRET_PATH/userstore.pw )
CONFIGSTORE_PW=$( cat $SECRET_PATH/configstore.pw )

SELFMANAGEMENT_PW=$( cat $SECRET_PATH/selfmanagement.pw )
SUPPORT_PW=$( cat $SECRET_PATH/support.pw )
IDCHECK_PW=$( cat $SECRET_PATH/idcheck.pw )
SWISSIDAPP_PW=$( cat $SECRET_PATH/swissidapp.pw )

BACKUP_PW=$( cat $SECRET_PATH/backup.pw )
MONITOR_PW=$( cat $SECRET_PATH/monitor.pw )

ACCOUNTMGR_PW=$( cat $SECRET_PATH/accountmgr.pw )


update_swissid_passwords_configstore() {
  echo "*** Updating SwissID LDAP passwords - configstore"
  bin/ldapmodify --continueOnError -h localhost -p 1389 -D "cn=Directory Manager" -j ${DIR_MANAGER_PW_FILE} <<EOF
dn: uid=am-config,ou=admins,$BASE_DN
changetype: modify
replace: userPassword
userPassword: $CONFIGSTORE_PW

dn: uid=backup,ou=admins,$BASE_DN
changetype: modify
replace: userPassword
userPassword: $BACKUP_PW

dn: uid=jmxmonitoring,ou=admins,$BASE_DN
changetype: modify
replace: userPassword
userPassword: $MONITOR_PW

EOF
}

update_swissid_passwords_ctsstore() {
  echo "*** Updating SwissID LDAP passwords - ctsstore"
  bin/ldapmodify --continueOnError -h localhost -p 1389 -D "cn=Directory Manager" -j ${DIR_MANAGER_PW_FILE} <<EOF
dn: uid=openam_cts,ou=admins,ou=famrecords,ou=openam-session,ou=tokens,$BASE_DN
changetype: modify
replace: userPassword
userPassword: $CTS_PW

dn: uid=backup,ou=admins,ou=famrecords,ou=openam-session,ou=tokens,$BASE_DN
changetype: modify
replace: userPassword
userPassword: $BACKUP_PW

dn: uid=jmxmonitoring,ou=admins,ou=famrecords,ou=openam-session,ou=tokens,$BASE_DN
changetype: modify
replace: userPassword
userPassword: $MONITOR_PW

EOF
}

update_swissid_passwords_userstore() {
  echo "*** Updating SwissID LDAP passwords - userstore"
  bin/ldapmodify --continueOnError -h localhost -p 1389 -D "cn=Directory Manager" -j ${DIR_MANAGER_PW_FILE} <<EOF
dn: uid=am-identity-bind-account,ou=admins,$BASE_DN
changetype: modify
replace: userPassword
userPassword: $USERSTORE_PW

dn: uid=backup,ou=admins,$BASE_DN
changetype: modify
replace: userPassword
userPassword: $BACKUP_PW

dn: uid=jmxmonitoring,ou=admins,$BASE_DN
changetype: modify
replace: userPassword
userPassword: $MONITOR_PW

dn: uid=selfmanagement,ou=admins,$BASE_DN
changetype: modify
replace: userPassword
userPassword: $SELFMANAGEMENT_PW

dn: uid=support,ou=admins,$BASE_DN
changetype: modify
replace: userPassword
userPassword: $SUPPORT_PW

dn: uid=idcheck,ou=admins,$BASE_DN
changetype: modify
replace: userPassword
userPassword: $IDCHECK_PW

dn: uid=swissidapp,ou=admins,$BASE_DN
changetype: modify
replace: userPassword
userPassword: $SWISSIDAPP_PW

dn: uid=accountmanager,ou=people,$BASE_DN
changetype: modify
replace: userPassword
userPassword: $ACCOUNTMGR_PW

EOF
}

load_swissid_store_ldifs() {
    STORE=$1
    if [ -d "swissid/ldif/$STORE" ]; then
        for LDIF in swissid/ldif/$STORE/*.ldif
        do
            echo "*** Loading ${LDIF}"
            sed -e "s/@BASE_DN@/$BASE_DN/" ${LDIF} >/tmp/file.ldif
            bin/ldapmodify --continueOnError -h localhost -p 1389 -D "cn=Directory Manager" -j ${DIR_MANAGER_PW_FILE} /tmp/file.ldif
            rm -f /tmp/file.ldif
        done
    else
        echo "*** No LDIFs for $STORE, skipping ..."
    fi
}

init_swissid() {
    # figure out on which stateful set server we are
    # code stolen from https://kubernetes.io/docs/tasks/run-application/run-replicated-stateful-application/
    [[ `hostname` =~ -([0-9]+) ]]
    ORDINAL=${BASH_REMATCH[1]}

    if [ "$ORDINAL" != "0" ]; then
        echo "*** We are not on the first $DJ_INSTANCE replica server, skipping SwissID initialization ..."
        exit 0
    fi

    # BASE_DN is set via swissid-gitlab/*store.yaml (baseDN: setting)
    echo "BASE_DN = $BASE_DN"

    update_swissid_passwords_$DJ_INSTANCE
    load_swissid_store_ldifs $DJ_INSTANCE
}
