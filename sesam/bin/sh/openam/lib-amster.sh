#!/usr/bin/env bash

##############################################################################
# Global variables
##############################################################################

AMSTER_DIR=${OPENAM_CONFIG_DIR}/amster
AMSTER_CONFIG_DIR=$CONFIG_DIR/amster

##############################################################################
# Deploy Amster
##############################################################################

function deploy_amster() {
    echo "*** Deploying Amster..."

    echo "     o remove existing folder"
	  rm -rf ${AMSTER_DIR}

    echo "     o extracting"
  	unzip -q $SOFTWARE_DIR/Amster-${AMSTER_VERSION}.zip -d ${AMSTER_DIR}

    echo "     o modify authorized_keys to remove ip-range limitation"
    sed -i.bak -e 's/from=\"127.0.0.0\/24,::1" //g' ${OPENAM_CONFIG_DIR}/authorized_keys
}

##############################################################################
# Configure OAuth2 provider
##############################################################################

function configure_oauth2_provider() {
	local tmp_script=/tmp/import.amster

    echo "*** Configure OAuth2 Provider..."

    echo "     o create Amster script"
cat > ${tmp_script} << EOF
connect --private-key ${OPENAM_CONFIG_DIR}/amster_rsa ${OPENAM_SERVER_URL}${OPENAM_DEPLOYMENT_URI}
import-config --path ${CONFIG_DIR}/openam/OAuth2Provider.json
:quit
EOF

    echo "     o execute Amster"
    ${AMSTER_DIR}/amster ${tmp_script} -Djavax.net.ssl.trustStore=${CACERTS_FILE} -Djavax.net.ssl.trustStore.password=${CACERTS_PASSWORD} -Djavax.net.ssl.trustStoreType=jks

    echo "     o remove Amster script"
    rm -f ${tmp_script}
}

##############################################################################
# Wait until OpenAM is up and running
##############################################################################

function wait_until_openam_alive() {
	echo "*** Wait until OpenAM Server is up and running..."
	curl -k --retry 2 "${OPENAM_SERVER_URL}${OPENAM_DEPLOYMENT_URI}/isAlive.jsp"
}
