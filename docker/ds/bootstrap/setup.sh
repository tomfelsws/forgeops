#!/bin/sh


# Add hostnames to the docker containers /etc/hosts - needed only for building.
echo "127.0.0.1 dsrs1.example.com dsrs2.example.com" >>/etc/hosts

echo "##### Cleaning all servers..."
./clean-all.sh


echo "##### Configuring directory server DSRS 1..."
./setup-ds.sh dsrs 1 10

# Set this to configuration replication at docker build time. Comment out to configure just a single server.
CONFIG_REPLICATION="yes"

if [ -n "$CONFIG_REPLICATION" ]; then 

    echo "##### Configuring directory server DSRS 2..."
    ./setup-ds.sh dsrs 2

    echo "##### Configuring replication between DSRS 1 and DSRS 2..."
    ./run/dsrs1/bin/dsreplication configure \
        -I admin -w password -X \
        --bindDn1 "cn=directory manager" --bindPassword1 password \
        --bindDn2 "cn=directory manager" --bindPassword2 password \
        --baseDn $BASE_DN \
        --baseDn $CTS_BASE_DN \
        --baseDn $CS_BASE_DN \
        --baseDn dc=openidm,dc=example,dc=com \
        --host1 dsrs1.example.com --port1 1444 --replicationPort1 1989 \
        --host2 dsrs2.example.com --port2 2444 --replicationPort2 2989 \
        --no-prompt

    echo "##### Initializing replication between DSRS 1 and DSRS 2..."
    ./run/dsrs1/bin/dsreplication initialize-all \
        -I admin -w password -X \
        --baseDn $BASE_DN \
        --baseDn $CTS_BASE_DN \
        --baseDn $CS_BASE_DN \
        --baseDn dc=openidm,dc=example,dc=com \
        --hostname dsrs1.example.com --port 1444 \
        --no-prompt

    echo "##### Stopping all servers..."
    ./stop-all.sh 

    echo "Setting replication purge delay to 12 hours"
    (cd run/dsrs1 &&  ./bin/dsconfig \
        set-replication-server-prop \
      --provider-name Multimaster\ Synchronization \
      --set replication-purge-delay:12\ h \
      --offline \
      --no-prompt)
fi

# Occasiionally we see build issues with timing. Wait a bit before shutdown.
sleep 5

echo "##### Stopping all servers..."
./stop-all.sh

convert_to_template()
{
    cd run/$1

    pwd

    # TODO: Is it enough to just remove changelogDb/*
    for i in changelogDb/*.dom/*.server; do
        rm -rf $i
    done

    rm -rf changelogDb/changenumberindex/*

    echo "Converting $1 config.ldif to use commons configuration"

    # update config.ldif. continue on error is set so we keep applying the changes
    # Some of the configuration changes won't apply if replication is not being configured.
    BASE_DN_X=$( echo $BASE_DN | sed -e "s/,/\\\\\\\,/g")
    CS_BASE_DN_X=$( echo $CS_BASE_DN | sed -e "s/,/\\\\\\\,/g")
    CTS_BASE_DN_X=$( echo $CTS_BASE_DN | sed -e "s/,/\\\\\\\,/g")
    sed -e "s/@BASE_DN@/$BASE_DN_X/" -e "s/@CS_BASE_DN@/$CS_BASE_DN_X/" -e "s/@CTS_BASE_DN@/$CTS_BASE_DN_X/" ../../config-changes.ldif > ../../config-changes-sed.ldif
    ./bin/ldifmodify -c -o config/config.ldif.new config/config.ldif ../../config-changes-sed.ldif
    mv config/config.ldif.new config/config.ldif
    rm ../../config-changes-sed.ldif

    cd ../../
}


convert_to_template dsrs1

