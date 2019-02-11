#!/bin/bash

##############################################################################
# Set global variables
##############################################################################

BATCH_DIR=$(cd $(dirname "$0"); pwd)
LIBS_DIR=$BATCH_DIR/openam
CONFIG_DIR=$BATCH_DIR/../../config
SOFTWARE_DIR=$BATCH_DIR/../../software

##############################################################################
# Read environment configuration
##############################################################################

if [ -z "$1" ] ; then
    echo environment not defined, quitting...
	exit 1
fi

env_common_dir="${BATCH_DIR}/../../environments/common"
env_dir="${BATCH_DIR}/../../environments/$1"
server_to_configure=$2

# Multi-node change
echo "env_dir resolves to: ${env_dir}"

# Check if configuration folder exists
if ! stat ${env_common_dir} > /dev/null 2>&1 ; then
   	echo "Configuration folder [${env_common_dir}] not found, quitting..."
	exit 1
fi
if ! stat ${env_dir} > /dev/null 2>&1 ; then
   	echo "Configuration folder [${env_dir}] not found, quitting..."
	exit 1
fi

[ -f "${env_common_dir}/env.properties" ] && source "${env_common_dir}/env.properties"
[ -f "${env_dir}/env.properties" ] && source "${env_dir}/env.properties"

# Multi-node change
echo "Node: $2"
[ -f "${env_common_dir}/${server_to_configure}" ] && source "${env_common_dir}/${server_to_configure}"
[ -f "${env_dir}/${server_to_configure}" ] && source "${env_dir}/${server_to_configure}"
echo "OPENAM_SERVER_URL: $OPENAM_SERVER_URL"

# Source all plugin-* scripts
for file in $LIBS_DIR/lib-*sh
do
    source ${file}
    if [ $? -ne 0 ]; then
        echo "Error sourcing library $file, quitting"
        exit 1
    fi
done

##############################################################################
# Start full deployment of OpenAM configurations
##############################################################################

if [ "$INSTALL_OPENAM_FROM_SCRATCH" = "true" ]; then
    echo "*************************************************************************"
    echo "***"
    echo "***   Setup OpenAM $OPENAM_VERSION"
    echo "***"
    echo "***   Server URL: $OPENAM_SERVER_URL"
    echo "***          Env: $1"
    #Multi-node scripting change
    echo "***          Server property: $2"
    echo "***"
    echo "***   Deployment is started (`date`)"
    echo "*************************************************************************"
    echo ""

    # Init OpenAM
    openam_init

    # Init JDK
    jdk_init
    checkrc

    # Generate configuration
    openam_generate_config

    # Generate SAML SP configuration
    samlsp_generate_config

    # Configure OpenAM Server
    openam_configure
    checkrc

    if [ "$CONFIG_TYPE" = "embedded" ]; then
      # load OpenDJ environment variables for primary userstore
      source ${BATCH_DIR}/opendj/lib-header-opendj.sh $1 opendj-userstore_1-primary.properties
      # correct some values set above to point to embedded OpenDJ installation instead
      opendjExtractTargetPath="$OPENAM_CONFIG_DIR/opends"
      binDir="$OPENAM_CONFIG_DIR/opends/bin"

      # create password file that is required for userstore setup
      source ${BATCH_DIR}/opendj/lib-shared-opendj.sh
      createPasswordFile

      # perform an embedded userstore setup
      source ${BATCH_DIR}/opendj/lib-userstore-opendj.sh
      userStoreSetup

      # perform final postOpenAM step for embedded config store
      source ${BATCH_DIR}/opendj/lib-configstore-opendj.sh
      configStorePostOpenam
    fi

    # Deploy SSO Admin Tool
    openam_deploy_ssoadm
    checkrc

    # Deploy Amster
    deploy_amster

    # Test OpenAM availability
    openam_test

    if [ "$CONFIGURE_OPENAM_CONFIG_STORE" = "yes" ]; then
        configure_openam_config_store
    fi

    # Configure external token store.
    # May need to do this on primary as well as secondary node/s as more token store nodes get added
    if [ "$CONFIGURE_TOKEN_STORE" = "yes" ]; then
        configure_token_store
    fi

    # Configurations (only on Primary node but not secondary nodes)
    if [ -z "$OPENAM_SERVER_URL_EXISTING" ]; then
        configure_site
        create_application_config
        configure_oauth2_relying_parties

        # Apply at the end
        if [ "$SECURITY_PERFORMANCE_HARDENING" = "yes" ]; then
            update_security_performance_settings
        fi
        update_primary_server_settings
        replace_openam_signing_keystore
        update_monitoring_settings

        if [ "$CONFIG_TYPE" != "embedded" ]; then
            # load OpenDJ environment variables for primary configstore
            source ${BATCH_DIR}/opendj/lib-header-opendj.sh $1 opendj-configstore_1-primary.properties
            # correct some values set above to point to primary configstore instead
            opendjExtractTargetPath="$CONFIGSTORE_DIR/opendj"
            binDir="$opendjExtractTargetPath/bin"
            passwordFile="${binDir}/.pass"
            # perform final postOpenAM step for config store, avoiding an extra DEPO job
            source ${BATCH_DIR}/opendj/lib-configstore-opendj.sh
            configStorePostOpenam
            # import any relying parties from the other side
            importRelyingParties

            # New install or upgrade: override server default and turn off affinity module for CTS
            # This will be turned on again from 2nd server below
            cts_affinity_mode_off
        fi

    fi

    # Perform configuration changes on secondary nodes only.
    # Some of the changes are done by the base script on primary node.
    if [ "$OPENAM_SERVER_URL_EXISTING" ]; then
        update_cookie_domain_for_secondary_node
        update_secondary_server_settings
        replace_openam_signing_keystore
        cts_affinity_mode_on
    fi
fi

# Steps to be done at the end
finalize

# Restart Tomcat at the end of setup
echo "*** Restarting Tomcat in $TOMCAT_DIR ..."
$TOMCAT_RESTART

# wait until OpenAM is up and running
wait_until_openam_alive

# configure OAuth2 provider
configure_oauth2_provider

echo "*************************************************************************"
echo "***"
echo "*** Deployment is finished (`date`)"
echo "***"
echo "*************************************************************************"
