#!/usr/bin/env bash

##############################################################################
# Global variables
##############################################################################

ssoadm_dir=${OPENAM_CONFIG_DIR}/${SSO_ADM}
ssoadm_bin=${ssoadm_dir}${OPENAM_DEPLOYMENT_URI}/bin/ssoadm
SSOADM=${ssoadm_bin}
SSOPWD=${ssoadm_dir}${OPENAM_DEPLOYMENT_URI}/bin/ampassword
openam_admin_psw_file=${OPENAM_CONFIG_DIR}/.pass
rest_admin_psw_file=${OPENAM_CONFIG_DIR}/rest.pass

config_generated_dir=$CONFIG_DIR/generated
config_auth_dir=$CONFIG_DIR/auth
config_auth_generated_dir=$CONFIG_DIR/generated_auth
samlsp_generated_dir=$CONFIG_DIR/../../conf/saml-sp

PUBLIC_KEY=$(cat $CONFIG_DIR/../../conf/test.pem | grep -v "BEGIN CERTIFICATE" | grep -v "END CERTIFICATE")
PUBLIC_KEY=$(echo $PUBLIC_KEY | tr -d ' ')

##############################################################################
# Utility functions
##############################################################################

try() {
		cmd=$*
		echo "EXEC: $cmd" >&2 ;
		eval ${cmd};
		exitcode=$?

		if [ ${exitcode} -ne 0 ]; then
				echo "" >&2;
				echo "Install aborted: command [$cmd] failed with error code $exitcode" >&2;
				echo "" >&2;
				exit 1
		fi
}

##############################################################################
# Init OpenAM
##############################################################################

function openam_init() {

	if stat ${OPENAM_CONFIG_DIR} > /dev/null 2>&1 ; then
		echo "*** Removing existing deployment"
		rm -rf ${OPENAM_CONFIG_DIR}
		checkrc
		tomcat_restart
		checkrc
	fi
	echo "*** Creating configuration directory (${OPENAM_CONFIG_DIR})"
	mkdir -p ${OPENAM_CONFIG_DIR}
}

##############################################################################
# Generate Configuration
##############################################################################

function openam_generate_config() {

    echo "*** Setting global variables"

    # Sesam
    SESAM_COOKIE_DOMAINS=iplanet-am-platform-cookie-domains=${PRIMARY_ALIAS}
    FQDN_MAPPING=com.sun.identity.server.fqdnMap[${PRIMARY_ALIAS}]=${PRIMARY_ALIAS}
    ORGANIZATION_ALIASES=sunOrganizationAliases=${PRIMARY_ALIAS}
    SWISSSIGN_SITE_SECONDARY_URLS="https://${PRIMARY_ALIAS}:443$OPENAM_DEPLOYMENT_URI"

    for i in $(echo ${SECONDARY_ALIAS} | sed "s/,/ /g")
    do
        SESAM_COOKIE_DOMAINS="iplanet-am-platform-cookie-domains=$i ${SESAM_COOKIE_DOMAINS}"
        FQDN_MAPPING="com.sun.identity.server.fqdnMap[$i]=$i ${FQDN_MAPPING}"
        ORGANIZATION_ALIASES="sunOrganizationAliases=$i ${ORGANIZATION_ALIASES}"
        SWISSSIGN_SITE_SECONDARY_URLS="https://${i}:443$OPENAM_DEPLOYMENT_URI  ${SWISSSIGN_SITE_SECONDARY_URLS}"
    done

    # Support
    SESAM_COOKIE_DOMAINS="${SESAM_COOKIE_DOMAINS} iplanet-am-platform-cookie-domains=${PRIMARY_ALIAS_SUPPORT}"
    FQDN_MAPPING="${FQDN_MAPPING} com.sun.identity.server.fqdnMap[${PRIMARY_ALIAS_SUPPORT}]=${PRIMARY_ALIAS_SUPPORT}"
    ORGANIZATION_ALIASES_SUPPORT=sunOrganizationAliases=${PRIMARY_ALIAS_SUPPORT}
    SWISSSIGN_SITE_SECONDARY_URLS="${SWISSSIGN_SITE_SECONDARY_URLS}  https://${PRIMARY_ALIAS_SUPPORT}:443$OPENAM_DEPLOYMENT_URI"

	for i in $(echo ${SECONDARY_ALIAS_SUPPORT} | sed "s/,/ /g")
	do
        SESAM_COOKIE_DOMAINS="iplanet-am-platform-cookie-domains=$i ${SESAM_COOKIE_DOMAINS}"
        FQDN_MAPPING="com.sun.identity.server.fqdnMap[$i]=$i ${FQDN_MAPPING}"
        ORGANIZATION_ALIASES_SUPPORT="sunOrganizationAliases=$i ${ORGANIZATION_ALIASES_SUPPORT}"
        SWISSSIGN_SITE_SECONDARY_URLS="https://${i}:443$OPENAM_DEPLOYMENT_URI  ${SWISSSIGN_SITE_SECONDARY_URLS}"
	done

	# Valid Goto Domains
	VALID_GOTO_URLS=""
	for i in $(echo ${VALID_GOTO_DOMAINS} | sed "s/,/ /g")
	do
		VALID_GOTO_URLS="openam-auth-valid-goto-resources=https://$i:*/* openam-auth-valid-goto-resources=https://$i:*/*?* ${VALID_GOTO_URLS}"
	done

    echo      "o SESAM_COOKIE_DOMAINS = ${SESAM_COOKIE_DOMAINS}"
    echo      "o FQDN_MAPPING = ${FQDN_MAPPING}"
    echo      "o ORGANIZATION_ALIASES = ${ORGANIZATION_ALIASES}"
    echo      "o ORGANIZATION_ALIASES_SUPPORT = ${ORGANIZATION_ALIASES_SUPPORT}"
    echo      "o VALID_GOTO_URLS = ${VALID_GOTO_URLS}"
    echo      "o SWISSSIGN_SITE_SECONDARY_URLS = ${SWISSSIGN_SITE_SECONDARY_URLS}"

    echo "*** Generating configuration files"

    if stat ${config_generated_dir} > /dev/null 2>&1 ; then
        rm -rf ${config_generated_dir}
    fi

    if stat ${config_auth_generated_dir} > /dev/null 2>&1 ; then
        rm -rf ${config_auth_generated_dir}
    fi

	mkdir ${config_generated_dir}
	mkdir ${config_auth_generated_dir}

	for file in ${CONFIG_DIR}/openam/*
	do
        echo "     o $(basename $file)"
		sed -e "s|{OPENAM_SERVER_URL}|${OPENAM_SERVER_URL}|g" \
			-e "s|{OPENAM_DEPLOYMENT_URI}|${OPENAM_DEPLOYMENT_URI}|g" \
			-e "s|{USERSTORE_SUFFIX}|${USERSTORE_SUFFIX}|g" \
			-e "s|{SESAM_SERVER_URL}|${SESAM_SERVER_URL}|g" \
			-e "s|{SESAM_SERVER_URL_SSL}|${SESAM_SERVER_URL_SSL}|g" \
			-e "s|{SESAM_SAML_SP_SERVER_URL}|${SESAM_SAML_SP_SERVER_URL}|g" \
			-e "s|{PUBLIC_KEY}|${PUBLIC_KEY}|g" \
			-e "s|{OPENAM_LB_HOST}|${OPENAM_LB_HOST}|g" \
			-e "s|{SESAM_COOKIE_DOMAINS}|${SESAM_COOKIE_DOMAINS}|g" \
			-e "s|{FQDN_MAPPING}|${FQDN_MAPPING}|g" \
			-e "s|{ORGANIZATION_ALIASES}|${ORGANIZATION_ALIASES}|g" \
			-e "s|{ORGANIZATION_ALIASES_SUPPORT}|${ORGANIZATION_ALIASES_SUPPORT}|g" \
			-e "s|{OPENAM_DEBUG_LEVEL}|${OPENAM_DEBUG_LEVEL}|g" \
			-e "s|{OPENAM_COOKIE_NAME}|${OPENAM_COOKIE_NAME}|g" \
			-e "s|{OPENAM_COOKIE_SECURE}|${OPENAM_COOKIE_SECURE}|g" \
			-e "s|{EXTERNAL_APP_URL}|${EXTERNAL_APP_URL}|g" \
			-e "s|{EXTERNAL_APP_URL_NON_SSL}|${EXTERNAL_APP_URL_NON_SSL}|g" \
			-e "s|{REALM_NAME}|${REALM_NAME}|g" \
			-e "s|{REALM_NAME_SUPPORT}|${REALM_NAME_SUPPORT}|g" \
			-e "s|{SUPPORT_COOKIE_DOMAINS}|${SUPPORT_COOKIE_DOMAINS}|g" \
			-e "s|{EXTERNAL_APP_URL_SUPPORT}|${EXTERNAL_APP_URL_SUPPORT}|g" \
			-e "s|{EXTERNAL_APP_URL_SUPPORT_NON_SSL}|${EXTERNAL_APP_URL_SUPPORT_NON_SSL}|g" \
			-e "s|{CONFIG_GENERATED_DIR}|${config_generated_dir}|g" \
			-e "s|{CONFIG_AUTH_GENERATED_DIR}|${config_auth_generated_dir}|g" \
			-e "s|{PRIMARY_ALIAS}|${PRIMARY_ALIAS}|g" \
			-e "s|{PRIMARY_ALIAS_SUPPORT}|${PRIMARY_ALIAS_SUPPORT}|g" \
			-e "s|{SESAM_SUCCESS_URL_SSL}|${SESAM_SUCCESS_URL_SSL}|g" \
			-e "s|{COOKIE_DOMAINS}|${COOKIE_DOMAINS}|g" \
			-e "s|{WEB_AGENT_NAME}|${WEB_AGENT_NAME}|g" \
			-e "s|{WEB_AGENT_NAME_SUPPORT}|${WEB_AGENT_NAME_SUPPORT}|g" \
			-e "s|{CLIENT_OAUTH2_SESAM_PASSWORD}|${CLIENT_OAUTH2_SESAM_PASSWORD}|g" \
			-e "s|{CLIENT_OAUTH2_AMSOCIAL_PASSWORD}|${CLIENT_OAUTH2_AMSOCIAL_PASSWORD}|g" \
			-e "s|{CLIENT_OAUTH2_SWISSIDAPP_PASSWORD}|${CLIENT_OAUTH2_SWISSIDAPP_PASSWORD}|g" \
			-e "s|{CLIENT_OAUTH2_KLP_PASSWORD}|${CLIENT_OAUTH2_KLP_PASSWORD}|g" \
			-e "s|{AGENT_WEB_SESAM_PASSWORD}|${AGENT_WEB_SESAM_PASSWORD}|g" \
			-e "s|{WEB_AGENT_CDSSO_COOKIE_DOMAIN_0}|${WEB_AGENT_CDSSO_COOKIE_DOMAIN_0}|g" \
			-e "s|{WEB_AGENT_CDSSO_COOKIE_DOMAIN_1}|${WEB_AGENT_CDSSO_COOKIE_DOMAIN_1}|g" \
			-e "s|{AGENT_WEB_SUPPORT_PASSWORD}|${AGENT_WEB_SUPPORT_PASSWORD}|g" \
			-e "s|{WEB_AGENT_SUPPORT_CDSSO_COOKIE_DOMAIN_0}|${WEB_AGENT_SUPPORT_CDSSO_COOKIE_DOMAIN_0}|g" \
			-e "s|{WEB_AGENT_SUPPORT_CDSSO_COOKIE_DOMAIN_1}|${WEB_AGENT_SUPPORT_CDSSO_COOKIE_DOMAIN_1}|g" \
			-e "s|{SWISSID_CAPTCHA_SECRET_KEY}|${SWISSID_CAPTCHA_SECRET_KEY}|g" \
			-e "s|{SWISSID_CAPTCHA_SITE_KEY}|${SWISSID_CAPTCHA_SITE_KEY}|g" \
			-e "s|{PUSHNOTIFICATION_APPLE_ENDPOINT}|${PUSHNOTIFICATION_APPLE_ENDPOINT}|g" \
			-e "s|{PUSHNOTIFICATION_GOOGLE_ENDPOINT}|${PUSHNOTIFICATION_GOOGLE_ENDPOINT}|g" \
			-e "s|{PUSHNOTIFICATION_SERVICE_SECRET}|${PUSHNOTIFICATION_SERVICE_SECRET}|g" \
			-e "s|{PUSHNOTIFICATION_SERVICE_ACCESSKEY}|${PUSHNOTIFICATION_SERVICE_ACCESSKEY}|g" \
			-e "s|{MAILSERVICE_SMTP_HOSTNAME}|${MAILSERVICE_SMTP_HOSTNAME}|g" \
			-e "s|{MAILSERVICE_SMTP_FROM_ADDRESS}|${MAILSERVICE_SMTP_FROM_ADDRESS}|g" \
			-e "s|{SESAM_HOTP_PASSWORD_DELIVERY}|${SESAM_HOTP_PASSWORD_DELIVERY}|g" \
			-e "s|{SESAM_HOTP_SMTP_HOSTNAME}|${SESAM_HOTP_SMTP_HOSTNAME}|g" \
			-e "s|{SESAM_HOTP_CARRIER_ATTRIBUTE}|${SESAM_HOTP_CARRIER_ATTRIBUTE}|g" \
			-e "s|{SESAM_HOTP_SMTP_FROM_ADDRESS}|${SESAM_HOTP_SMTP_FROM_ADDRESS}|g" \
			-e "s|{FORGEROCK_HOTP_SMTP_HOSTNAME}|${FORGEROCK_HOTP_SMTP_HOSTNAME}|g" \
			-e "s|{FORGEROCK_HOTP_CARRIER_ATTRIBUTE}|${FORGEROCK_HOTP_CARRIER_ATTRIBUTE}|g" \
			-e "s|{FORGEROCK_HOTP_SMTP_FROM_ADDRESS}|${FORGEROCK_HOTP_SMTP_FROM_ADDRESS}|g" \
			-e "s|{FORGEROCK_OATH_ISSUER_NAME}|${FORGEROCK_OATH_ISSUER_NAME}|g" \
			-e "s|{REST_ADMIN_USER}|${REST_ADMIN_USER}|g" \
			${CONFIG_DIR}/openam/$(basename $file) > ${config_generated_dir}/$(basename $file)
	done

	echo "*** Generating auth configuration files"

	for file in ${CONFIG_DIR}/auth/*
	do
        echo "     o $(basename $file)"
		sed -e "s|{SWISSID_CAPTCHA_SITE_KEY}|${SWISSID_CAPTCHA_SITE_KEY}|g" \
			-e "s|{SWISSID_CAPTCHA_SECRET_KEY}|${SWISSID_CAPTCHA_SECRET_KEY}|g" \
			${CONFIG_DIR}/auth/$(basename $file) > ${config_auth_generated_dir}/$(basename $file)
	done

  echo "*** Converting generated files in unix format"
	dos2unix ${config_generated_dir}/*
	dos2unix ${config_auth_generated_dir}/*
}

##############################################################################
# Generate SAML SP Configuration
##############################################################################

function samlsp_generate_config() {

    echo "*** Generating SAML SP configuration files"

    echo "     o removing existing configuration"
    if stat ${samlsp_generated_dir} > /dev/null 2>&1 ; then
        rm -rf ${samlsp_generated_dir}
    fi
	mkdir ${samlsp_generated_dir}

	echo "     o replacing variables with environment specific values"
	for file in ${CONFIG_DIR}/saml-sp/*
	do
        echo "     o $(basename $file)"
		sed -e "s|{OPENAM_SERVER_URL}|${OPENAM_SERVER_URL}|g" \
			-e "s|{OPENAM_DEPLOYMENT_URI}|${OPENAM_DEPLOYMENT_URI}|g" \
			-e "s|{SESAM_SERVER_URL}|${SESAM_SERVER_URL}|g" \
			-e "s|{SESAM_SERVER_URL_SSL}|${SESAM_SERVER_URL_SSL}|g" \
			-e "s|{SESAM_SAML_SP_SERVER_URL}|${SESAM_SAML_SP_SERVER_URL}|g" \
			-e "s|{OPENAM_CONFIG_DIR}|${OPENAM_CONFIG_DIR}|g" \
			-e "s|{PUBLIC_KEY}|${PUBLIC_KEY}|g" \
			${CONFIG_DIR}/saml-sp/$(basename $file) > ${samlsp_generated_dir}/$(basename $file)
	done

    echo "     o converting generated configuration in unix format"
    dos2unix ${samlsp_generated_dir}/*
}


##############################################################################
# Configure OpenAM
##############################################################################

function openam_configure() {

	echo "*** Deploying SSO Configurator Tool"
	local ssoconf_dir=${OPENAM_CONFIG_DIR}/${SSO_CONF}
	rm -rf ${ssoconf_dir}
	unzip -q $SOFTWARE_DIR/${SSO_CONF_ZIP_FILE} -d ${ssoconf_dir}

	echo "*** Replacing variables in openam.properties template with environment specific values"
	sed -e "s|{OPENAM_SERVER_URL}|${OPENAM_SERVER_URL}|g" \
		-e "s|{OPENAM_DEPLOYMENT_URI}|${OPENAM_DEPLOYMENT_URI}|g" \
		-e "s|{OPENAM_CONFIG_DIR}|${OPENAM_CONFIG_DIR}|g" \
		-e "s|{OPENAM_ENC_KEY}|${OPENAM_ENC_KEY}|g" \
		-e "s|{OPENAM_ADMIN_PASSWD}|${OPENAM_ADMIN_PASSWD}|g" \
		-e "s|{OPENAM_LDAPUSER_PASSWD}|${OPENAM_LDAPUSER_PASSWD}|g" \
		-e "s|{OPENAM_COOKIE_DOMAIN}|${OPENAM_COOKIE_DOMAIN}|g" \
		-e "s|{CONFIG_TYPE}|${CONFIG_TYPE}|g" \
		-e "s|{CONFIG_SSL}|${CONFIG_SSL}|g" \
		-e "s|{CONFIG_HOST}|${CONFIG_HOST}|g" \
		-e "s|{CONFIG_PORT}|${CONFIG_PORT}|g" \
		-e "s|{CONFIG_ADMIN_PORT}|${CONFIG_ADMIN_PORT}|g" \
		-e "s|{CONFIG_JMX_PORT}|${CONFIG_JMX_PORT}|g" \
		-e "s|{CONFIG_SUFFIX}|${CONFIG_SUFFIX}|g" \
		-e "s|{CONFIG_ADMIN}|${CONFIG_ADMIN}|g" \
		-e "s|{CONFIG_PASSWD}|${CONFIG_PASSWD}|g" \
		-e "s|{USERSTORE_SSL}|${USERSTORE_SSL}|g" \
		-e "s|{USERSTORE_HOST}|${USERSTORE_HOST}|g" \
		-e "s|{USERSTORE_PORT}|${USERSTORE_PORT}|g" \
		-e "s|{USERSTORE_SUFFIX}|${USERSTORE_SUFFIX}|g" \
		-e "s|{USERSTORE_ADMIN}|${USERSTORE_ADMIN}|g" \
		-e "s|{USERSTORE_PASSWD}|${USERSTORE_PASSWD}|g" \
		-e "s|{LB_SITE_NAME}|${LB_SITE_NAME}|g" \
		-e "s|{LB_PRIMARY_URL}|${LB_PRIMARY_URL}|g" \
		$SOFTWARE_DIR/openam.properties.template > ${ssoconf_dir}/openam.properties

	echo "*** Configuring OpenAM "
	java -jar -Djavax.net.ssl.trustStore=${CACERTS_FILE} -Djavax.net.ssl.trustStorePassword=$CACERTS_PASSWORD $ssoconf_dir/${SSO_CONF_JAR_FILE} \
		-f ${ssoconf_dir}/openam.properties

	echo "*** Creating password file (${openam_admin_psw_file})"
	echo ${OPENAM_ADMIN_PASSWD} | cat > ${openam_admin_psw_file}
	chmod 400 ${openam_admin_psw_file}

	echo "*** Creating rest admin file (${rest_admin_psw_file})"
	echo ${REST_ADMIN_PWD} | cat > ${rest_admin_psw_file}
	chmod 400 ${rest_admin_psw_file}
}

##############################################################################
# Deploy SSO Administration Tool
##############################################################################

function openam_deploy_ssoadm() {

	rm -rf ${ssoadm_dir}
	echo "*** Deploying SSO Administration Tool"
    echo "     o extracting"
	unzip -q $SOFTWARE_DIR/${SSO_ADM_ZIP_FILE} -d ${ssoadm_dir}

    cd $ssoadm_dir
    checkrc

    echo "     o setting up"
    echo ./setup -p ${OPENAM_CONFIG_DIR} -d ${ssoadm_dir}${OPENAM_DEPLOYMENT_URI}/debug -l ${ssoadm_dir}${OPENAM_DEPLOYMENT_URI}/log --acceptLicense
    ./setup -p ${OPENAM_CONFIG_DIR} -d ${ssoadm_dir}${OPENAM_DEPLOYMENT_URI}/debug -l ${ssoadm_dir}${OPENAM_DEPLOYMENT_URI}/log --acceptLicense

    if [ ! -x $ssoadm_bin ]; then
        echo "ERROR: $ssoadm_bin not working correctly"
        return 1
    fi

    # on virtual machines when java uses /dev/random it can be very slow
	# Commented as code moved to patch_ssoadm() function
    #perl -pi -e "s#com.sun.identity.cli.CommandManager#-D\"java.security.egd=file:/dev/./urandom\" com.sun.identity.cli.CommandManager#" $ssoadm_bin
    patch_ssoadm

}

patch_ssoadm() {
	echo "*** Patching ssoadm"
	ENCODED_SITE_URL=$(echo ${LB_PRIMARY_URL} | sed -e 's/\//\\\\\//g')
	ENCODED_HOST=$(echo ${OPENAM_SERVER_URL}${OPENAM_DEPLOYMENT_URI} | sed -e 's/\//\\\\\//g')
	ENCODED_CACERTS_FILE=$(echo ${CACERTS_FILE} | sed -e 's/\//\\\\\//g')

	echo "     o ENCODED_SITE_URL : $ENCODED_SITE_URL  ENCODED_HOST: $ENCODED_HOST    ssoadm_bin: $ssoadm_bin "

	# on virtual machines when java uses /dev/random it can be very slow. Hence use -D "java.security.egd=file:/dev/./urandom"
	# Add JVM specific parameters to prevent issue due to disabling module based auth in root realm
	# Add site to server mapping in front of the line containing  om.sun.identity.cli.CommandManager

	# Re change {-e \"s/EXT_CLASSPATH=/EXT_CLASSPATH_TEMPORARY_CHANGE=/\"} below, this is a temporary hack in the OpenAM ssoadm script to ignore any external (i.e. DEPO) jars in the classpath to suppress excessive logging by DEPO..The recomended DEPO level fix for this issue is being investigated by Gianluca Germana from POST IT team.
	try "sed -e \"s/com.sun.identity.cli.CommandManager/-D\\\"java.security.egd=file:\\/dev\\/.\\/urandom\\\" -D\\\"javax.net.ssl.trustStore=${ENCODED_CACERTS_FILE}\\\" -D\\\"javax.net.ssl.trustStorePassword=$CACERTS_PASSWORD\\\" -D\\\"org.forgerock.openam.ssoadm.auth.indexType=service\\\"  -D\\\"org.forgerock.openam.ssoadm.auth.indexName=ldapService\\\"  -D\\\"com.iplanet.am.naming.map.site.to.server=${ENCODED_SITE_URL}=${ENCODED_HOST}\\\"   com.sun.identity.cli.CommandManager/\"  -e \"s/EXT_CLASSPATH=/EXT_CLASSPATH_TEMPORARY_CHANGE=/\" ${ssoadm_bin} > \"${ssoadm_dir}${OPENAM_DEPLOYMENT_URI}/bin/ssoadm-new\" "

	chmod 744 ${ssoadm_dir}${OPENAM_DEPLOYMENT_URI}/bin/ssoadm-new

	rm ${ssoadm_bin}
	mv ${ssoadm_dir}${OPENAM_DEPLOYMENT_URI}/bin/ssoadm-new ${ssoadm_bin}

	#echo "Testing ssoadm setup.. Listing servers in the deployment.."
	#$ssoadm_bin list-servers -u amadmin -f ${openam_admin_psw_file}

	echo "     o  patching done"
}

configure_site() {
	echo "*** Configuring site"

	echo "     o Site secondary URL to be set: ${SWISSSIGN_SITE_SECONDARY_URLS}"
	try "$SSOADM add-site-sec-urls -u amadmin -f ${openam_admin_psw_file} --sitename $LB_SITE_NAME -a \"${SWISSSIGN_SITE_SECONDARY_URLS}\""
}

update_cookie_domain_for_secondary_node() {
	echo "*** Updating Cookie Domain for secondary node site"

	CURRENT_COOKIE_DOMAINS=$(try "$SSOADM get-attr-defs -u amadmin -f ${openam_admin_psw_file} -s iPlanetAMPlatformService -t global -a iplanet-am-platform-cookie-domains")
	echo "     o CURRENT_COOKIE_DOMAINS: ${CURRENT_COOKIE_DOMAINS}"
	SESAM_COOKIE_DOMAINS=$(echo ${CURRENT_COOKIE_DOMAINS}  | sed 's/Schema attribute defaults were returned./ /g')
	echo "     o SESAM_COOKIE_DOMAINS: ${SESAM_COOKIE_DOMAINS}"

	echo "     o executing: $SSOADM set-attr-defs -u amadmin -f ${openam_admin_psw_file} -s iPlanetAMPlatformService -t global -a iplanet-am-platform-cookie-domains=$OPENAM_COOKIE_DOMAIN ${SESAM_COOKIE_DOMAINS} "
	try "$SSOADM set-attr-defs -u amadmin -f ${openam_admin_psw_file} -s iPlanetAMPlatformService -t global -a iplanet-am-platform-cookie-domains=$OPENAM_COOKIE_DOMAIN ${SESAM_COOKIE_DOMAINS} "
}

update_security_performance_settings() {
	echo "*** Updating Security performance settings"

	try "$SSOADM  update-server-cfg -u amadmin -f ${openam_admin_psw_file} --servername default -a com.iplanet.am.cookie.name=$OPENAM_COOKIE_NAME com.iplanet.am.cookie.secure=true com.iplanet.am.lbcookie.name=$OPENAM_LB_COOKIE_NAME openam.auth.soap.rest.generic.authentication.exception=true com.sun.identity.sm.notification.threadpool.size=20 com.iplanet.am.notification.threadpool.size=30  "
	try "$SSOADM  update-server-cfg -u amadmin -f ${openam_admin_psw_file} --servername default -a com.iplanet.services.configpath=${OPENAM_CONFIG_DIR} com.iplanet.services.debug.directory=${OPENAM_CONFIG_DIR}${OPENAM_DEPLOYMENT_URI}/debug com.iplanet.services.stats.directory=${OPENAM_CONFIG_DIR}${OPENAM_DEPLOYMENT_URI}/stats com.sun.identity.sm.flatfile.root_dir=${OPENAM_CONFIG_DIR}${OPENAM_DEPLOYMENT_URI}/sms  "

	try "$SSOADM set-attr-defs -u amadmin -f ${openam_admin_psw_file} -s iPlanetAMAuthService -t Global -a iplanet-am-auth-ldap-connection-pool-default-size=10:65 "

	try "$SSOADM set-attr-defs -u amadmin -f ${openam_admin_psw_file} -s iPlanetAMAuthService -t Organization -a sunEnableModuleBasedAuth=false "
	try "$SSOADM set-realm-svc-attrs -u amadmin -f ${openam_admin_psw_file} -e / -s iPlanetAMAuthService -a sunEnableModuleBasedAuth=false "
	try "$SSOADM set-realm-svc-attrs -u amadmin -f ${openam_admin_psw_file} -e $REALM_NAME -s iPlanetAMAuthService -a sunEnableModuleBasedAuth=false "
	try "$SSOADM set-realm-svc-attrs -u amadmin -f ${openam_admin_psw_file} -e $REALM_NAME_SUPPORT -s iPlanetAMAuthService -a sunEnableModuleBasedAuth=false "

	#Note: Re-enabled after fix for https://jira.post.ch/browse/SES-1255
	try "$SSOADM set-attr-defs -u amadmin -f ${openam_admin_psw_file} -s iPlanetAMSessionService -t global -a iplanet-am-session-enable-session-constraint=ON iplanet-am-session-constraint-resulting-behavior=DENY_ACCESS"
	try "$SSOADM set-attr-defs -u amadmin -f ${openam_admin_psw_file} -s iPlanetAMSessionService -t dynamic -a iplanet-am-session-quota-limit=100 iplanet-am-session-max-idle-time=10 "
}

replace_openam_signing_keystore() {
	# generate signing keystore password file
	# this is required during setup of secondary OpenAM
	# see SES-1852 comments for details
	echo "     o create signing keystore password file"
	echo $SWISSID_OPENAM_KEYSTORE_PASSWORD > ${SWISSID_OPENAM_KEYSTORE_PASSWORD_FILE}
	chmod 400 ${SWISSID_OPENAM_KEYSTORE_PASSWORD_FILE}

	echo "     o update server configuration with new signing keystore filename and passwords"
	try "$SSOADM update-server-cfg -u amadmin -f ${openam_admin_psw_file} --servername ${OPENAM_SERVER_URL}$OPENAM_DEPLOYMENT_URI -a com.sun.identity.saml.xmlsig.keystore=$SWISSID_OPENAM_KEYSTORE_FILE com.sun.identity.saml.xmlsig.storetype=jceks com.sun.identity.saml.xmlsig.storepass=${SWISSID_OPENAM_KEYSTORE_PASSWORD_FILE} com.sun.identity.saml.xmlsig.keypass=${SWISSID_OPENAM_KEYSTORE_PASSWORD_FILE} "

	#echo "     o update OAuth2 provider configuration to use new signing key alias"
	#try "$SSOADM set-realm-svc-attrs -u amadmin -f ${openam_admin_psw_file} --realm $REALM_NAME -s OAuth2Provider --attributevalues forgerock-oauth2-provider-keypair-name=swissid-signer  "
}

update_monitoring_settings() {
	echo "*** Updating monitoring settings"
	try "$SSOADM  set-attr-defs -u amadmin -f ${openam_admin_psw_file}  --servicename iPlanetAMMonitoringService --schematype Global   -a iplanet-am-monitoring-snmp-enabled=true iplanet-am-monitoring-snmp-port=$OPENAM_SNMP_PORT iplanet-am-monitoring-enabled=true iplanet-am-monitoring-rmi-enabled=true iplanet-am-monitoring-rmi-port=$OPENAM_JMX_PORT "
}

# Note: Creating this function as the base script is unable to fully resolve %OPENAM_CONFIG_DIR%%OPENAM_DEPLOYMENT_URI%/debug when placed under 6-server-settings
# Fully resolved path is required to bypass the issue as per ForgeRock ticket: https://backstage.forgerock.com/support/tickets?id=22339
update_primary_server_settings() {
	echo "*** Updating primary server settings"
	try "$SSOADM  update-server-cfg -u amadmin -f ${openam_admin_psw_file} --servername ${OPENAM_SERVER_URL}$OPENAM_DEPLOYMENT_URI -a com.iplanet.services.debug.level=$OPENAM_DEBUG_LEVEL com.iplanet.services.debug.directory=${OPENAM_CONFIG_DIR}${OPENAM_DEPLOYMENT_URI}/debug com.iplanet.services.stats.directory=${OPENAM_CONFIG_DIR}${OPENAM_DEPLOYMENT_URI}/stats"

	#Adding hostname to fqdnMap to be able to test new deployments on individual nodes
	try "$SSOADM  update-server-cfg -u amadmin -f ${openam_admin_psw_file} --servername ${OPENAM_SERVER_URL}$OPENAM_DEPLOYMENT_URI -a com.sun.identity.server.fqdnMap[${OPENAM_COOKIE_DOMAIN}]=${OPENAM_COOKIE_DOMAIN} "
}

update_secondary_server_settings() {
	echo "*** Updating secondary server settings"
	try "$SSOADM  update-server-cfg -u amadmin -f ${openam_admin_psw_file} --servername ${OPENAM_SERVER_URL}$OPENAM_DEPLOYMENT_URI -a com.iplanet.services.debug.level=$OPENAM_DEBUG_LEVEL com.iplanet.services.debug.directory=${OPENAM_CONFIG_DIR}${OPENAM_DEPLOYMENT_URI}/debug com.iplanet.services.stats.directory=${OPENAM_CONFIG_DIR}${OPENAM_DEPLOYMENT_URI}/stats ${FQDN_MAPPING} "

	#Adding hostname to fqdnMap to be able to test new deployments on individual nodes
	try "$SSOADM  update-server-cfg -u amadmin -f ${openam_admin_psw_file} --servername ${OPENAM_SERVER_URL}$OPENAM_DEPLOYMENT_URI -a com.sun.identity.server.fqdnMap[${OPENAM_COOKIE_DOMAIN}]=${OPENAM_COOKIE_DOMAIN} "
}

configure_token_store() {
	echo "*** Configuring token store"
	#Rollback script
	#try "$SSOADM update-server-cfg -u amadmin -f {openam_admin_psw_file} -s default --attributevalues org.forgerock.services.cts.store.location=default"

	try "$SSOADM update-server-cfg -u amadmin -f ${openam_admin_psw_file} -s default --attributevalues org.forgerock.services.cts.store.location=${TOKEN_STORE_MODE} org.forgerock.services.cts.store.root.suffix=${TOKEN_STORE_ROOT_SUFFIX} org.forgerock.services.cts.store.ssl.enabled=${TOKEN_STORE_SSL}  org.forgerock.services.cts.store.directory.name=${TOKEN_STORE_CONNECTION_STRINGS} org.forgerock.services.cts.store.loginid=${TOKEN_STORE_LOGIN_ID}  org.forgerock.services.cts.store.password=${TOKEN_STORE_PASSWD}  org.forgerock.services.cts.store.max.connections=${TOKEN_STORE_MAX_CONNECTIONS} org.forgerock.services.cts.store.heartbeat=${TOKEN_STORE_HEART_BEAT} "

	try "$SSOADM  update-server-cfg -u amadmin -f ${openam_admin_psw_file} --servername default -a org.forgerock.services.cts.store.affinity.enabled=$TOKEN_STORE_AFFINITY_MODE_ENABLED "
}

cts_affinity_mode_off() {
	echo "*** Turning OFF CTS affinity mode on primary token store"
	try "$SSOADM update-server-cfg -u amadmin -f ${openam_admin_psw_file} --servername ${OPENAM_SERVER_URL}$OPENAM_DEPLOYMENT_URI --attributevalues org.forgerock.services.cts.store.directory.name=${TOKEN_STORE_CONNECTION_STRING_1} org.forgerock.services.cts.store.affinity.enabled=false"
}

cts_affinity_mode_on() {
	echo "*** Turning ON CTS affinity mode primary token store"
	try "$SSOADM remove-server-cfg -u amadmin -f ${openam_admin_psw_file} --servername ${OPENAM_SERVER_URL_EXISTING}$OPENAM_DEPLOYMENT_URI --propertynames org.forgerock.services.cts.store.directory.name org.forgerock.services.cts.store.affinity.enabled"
}

configure_openam_config_store() {
	echo "*** Configuring config store"
	#Template for server specific config:
	#$SSOADM update-server-cfg  -u amadmin -f  ${openam_admin_psw_file} -s <server> --attributevalues .....

	try "$SSOADM get-svrcfg-xml -u amadmin -f  ${openam_admin_psw_file} -s ${OPENAM_SERVER_URL}$OPENAM_DEPLOYMENT_URI -o ${OPENAM_CONFIG_DIR}/openam_server_cfg_1.xml "
	#echo "current config store configuration file.. this file will be modified"
	#cat ${OPENAM_CONFIG_DIR}/openam_server_cfg_1.xml

	sed -e "s/minConnPool=\"1\"/minConnPool=\"$CONFIG_STORE_MIN_CONNECTION_POOL\"/g" -e "s/maxConnPool=\"10\"/maxConnPool=\"$CONFIG_STORE_MAX_CONNECTION_POOL\"/g" ${OPENAM_CONFIG_DIR}/openam_server_cfg_1.xml > ${OPENAM_CONFIG_DIR}/openam_server_cfg_2.xml

	line_number_of_last_occurence_of_string=$(awk '/<User/{ print NR}' ${OPENAM_CONFIG_DIR}/openam_server_cfg_2.xml | tail -1)
	entry_location_string=$(echo "$line_number_of_last_occurence_of_string")i
	#echo "entry_location_string: $entry_location_string"

# WARNING: Indenting the below code block raises error > syntax error: unexpected end of file. Someone also reported it here: http://stackoverflow.com/questions/9886268/shell-script-syntax-error-unexpected-end-of-file . Search for EOF
# Unable to use sed command to insert text on some Operating systems, e.g. sed '26i\<Server 2>\' openam_server_cfg.xml
ed ${OPENAM_CONFIG_DIR}/openam_server_cfg_2.xml << END
$entry_location_string
		<Server name="Server2" host="$CONFIG_STORE_FAILOVER_SERVER" port="$CONFIG_STORE_FAILOVER_SERVER_PORT" type="$CONFIG_STORE_FAILOVER_SERVER_SSL_TYPE" />
.
w
q
END


	try "$SSOADM set-svrcfg-xml -u amadmin -f ${openam_admin_psw_file} -s ${OPENAM_SERVER_URL}$OPENAM_DEPLOYMENT_URI  -X ${OPENAM_CONFIG_DIR}/openam_server_cfg_2.xml "

	#echo "Just outputting the file used to update config store settings for troubleshooting purposes, as the generated files will be deleted."
	#cat ${OPENAM_CONFIG_DIR}/openam_server_cfg_2.xml

	rm -rf ${OPENAM_CONFIG_DIR}/openam_server_cfg_*.xml
}

configure_oauth2_relying_parties() {
	echo "*** Configuring OAuth2 Relying Parties"

	OIFS=$IFS
	IFS=','

	# Dynamically append environment and relyingParty specific redirect URIs to the RP configuration file
	relyingPartyArray=(${OAUTH2_RELYING_PARTIES})
	for relyingParty in ${relyingPartyArray[@]}
	do
		echo "relyingParty is $relyingParty"
		relyingPartyConfigFileGenerated="${config_generated_dir}/Agent_OAuth2Client.${relyingParty}.properties"
		#echo "relyingPartyConfigFileGenerated: ${relyingPartyConfigFileGenerated}"
		if [ -f ${env_dir}/relying-parties/$relyingParty/redirectURIs ]; then
			n=0
			while IFS='' read -r line || [[ -n "$line" ]]; do
		  	try "echo \"com.forgerock.openam.oauth2provider.redirectionURIs[$n]=$line\" >>   " ${relyingPartyConfigFileGenerated}
				((n++))
			done < ${env_dir}/relying-parties/$relyingParty/redirectURIs
		fi
		#Now create the RP client
		try "$SSOADM create-agent -u amadmin -f ${openam_admin_psw_file} --realm $REALM_NAME --agentname $relyingParty --agenttype OAuth2Client --datafile ${relyingPartyConfigFileGenerated}  "

	done
	IFS=$OIFS

	echo "*** Configured OAuth2 Relying Parties successfully"
}

configure_debug_files_logging() {
	echo "Inside configure_debug_files_logging() "
	rm -rf $OPENAM_CONFIG_DIR/debuglogging.configured
	echo "${OPENAM_CONFIG_DIR}${OPENAM_DEPLOYMENT_URI}/debug/* {" > ${OPENAM_CONFIG_DIR}/debuglogging.conf
	echo "   olddir ${OPENAM_CONFIG_DIR}${OPENAM_DEPLOYMENT_URI}/debug/rotated" >> ${OPENAM_CONFIG_DIR}/debuglogging.conf
	echo "   size $OPENAM_DEBUG_FILE_ROTATION_SIZE" >> ${OPENAM_CONFIG_DIR}/debuglogging.conf
	echo "   rotate $OPENAM_ROTATED_DEBUG_FILE_RETENTION_NUMBER" >> ${OPENAM_CONFIG_DIR}/debuglogging.conf
	echo "}" >> ${OPENAM_CONFIG_DIR}/debuglogging.conf

	# Check if logrotate cron job has already been configured
    logrotatecron=$(crontab -l | grep "debuglogging.conf")

	if [ "${logrotatecron}" ]; then
		echo "debug files rotation using logrotate already setup"
	else
		echo "setting up debug files rotation cron using logrotate"
		( crontab -l; echo "${OPENAM_DEBUG_FILE_LOGROTATE_CRON} [ -f ${OPENAM_CONFIG_DIR}/debuglogging.conf ] && /usr/sbin/logrotate -s ${OPENAM_CONFIG_DIR}/logrotate.status ${OPENAM_CONFIG_DIR}/debuglogging.conf") | crontab -
	fi

	mkdir ${OPENAM_CONFIG_DIR}${OPENAM_DEPLOYMENT_URI}/debug/rotated

	echo "............................."
}

# Not being used since logrotate setup to manage OpenAM debug files. This is useful when OpenAM debug properties is used to rotate files
configure_debug_files_housekeeping() {
    echo "Inside configure_debug_files_housekeeping() "

    # Check if backup housekeeping cron job has already been configured
    housekeeping=$(crontab -l | grep "$OPENAM_CONFIG_DIR$OPENAM_DEPLOYMENT_URI/debug")

    if [ "${housekeeping}" ]; then
        echo "debug files housekeeping already setup"
    else
        echo "setting up debug files housekeeping cron"
        ( crontab -l; echo "${OPENAM_ROTATED_DEBUG_FILE_HOUSEKEEPING_CRON} find $OPENAM_CONFIG_DIR$OPENAM_DEPLOYMENT_URI/debug -type f -mtime +$OPENAM_ROTATED_DEBUG_FILE_RETENTION_IN_DAYS -name \"*-[0-9][0-9].[0-9][0-9].[0-9][0-9][0-9][0-9]-[0-9][0-9].[0-9][0-9]_[0-9][0-9].[0-9][0-9][0-9]\" -exec rm -f '{}' \;") | crontab -
    fi

    echo "............................."
}


# Configuration steps to be performed at the end
finalize() {
	echo "*** Finalizing"
	# configure_debug_files_housekeeping
	configure_debug_files_logging
	# Bring back the server in load balancer pool, in order to serve traffic
	try "$SSOADM  update-server-cfg -u amadmin -f ${openam_admin_psw_file} --servername ${OPENAM_SERVER_URL}$OPENAM_DEPLOYMENT_URI -a active.loadbalancer.pool=$ADD_NODE_TO_LOADBALANCER_POOL_AFTER_DEPLOYMENT "
}
##############################################################################
# Create Application configuration
##############################################################################

function create_application_config() {
    echo "*** Creating Application configuration"

    echo "     o converting ssoadm batch scripts in unix format"
	dos2unix ${CONFIG_DIR}/ssoadm/*

    echo "     o execute ssoadm batch scripts"
	for script in ${CONFIG_DIR}/ssoadm/*
	do
        echo "     o execute $(basename $script)"
        while IFS='' read -r line || [[ -n "$line" ]]; do
            local new_line="${line/\%OPENAM_COOKIE_DOMAIN\%/${OPENAM_COOKIE_DOMAIN}}"
            new_line="${new_line/\%OPENAM_SERVER_URL\%/${OPENAM_SERVER_URL}}"
            new_line="${new_line/\%OPENAM_DEPLOYMENT_URI\%/${OPENAM_DEPLOYMENT_URI}}"
            new_line="${new_line/\%USERSTORE_SUFFIX\%/${USERSTORE_SUFFIX}}"
            new_line="${new_line/\%OPENAM_LB_HOST\%/${OPENAM_LB_HOST}}"
            new_line="${new_line/\%SESAM_COOKIE_DOMAINS\%/${SESAM_COOKIE_DOMAINS}}"
            new_line="${new_line/\%SUPPORT_COOKIE_DOMAINS\%/${SUPPORT_COOKIE_DOMAINS}}"
            new_line="${new_line/\%FQDN_MAPPING\%/${FQDN_MAPPING}}"
            new_line="${new_line/\%ORGANIZATION_ALIASES\%/${ORGANIZATION_ALIASES}}"
            new_line="${new_line/\%ORGANIZATION_ALIASES_SUPPORT\%/${ORGANIZATION_ALIASES_SUPPORT}}"
            new_line="${new_line/\%OPENAM_DEBUG_LEVEL\%/${OPENAM_DEBUG_LEVEL}}"
            new_line="${new_line/\%OPENAM_COOKIE_NAME\%/${OPENAM_COOKIE_NAME}}"
            new_line="${new_line/\%OPENAM_COOKIE_SECURE\%/${OPENAM_COOKIE_SECURE}}"
            new_line="${new_line//\%CONFIG_GENERATED_DIR\%/${config_generated_dir}}"
            new_line="${new_line/\%CONFIG_AUTH_GENERATED_DIR\%/${config_auth_generated_dir}}"
            new_line="${new_line/\%REALM_NAME\%/${REALM_NAME}}"
            new_line="${new_line/\%EXTERNAL_APP_URL\%/${EXTERNAL_APP_URL}}"
            new_line="${new_line/\%EXTERNAL_APP_URL_NON_SSL\%/${EXTERNAL_APP_URL_NON_SSL}}"
            new_line="${new_line/\%SESAM_SUCCESS_URL_SSL\%/${SESAM_SUCCESS_URL_SSL}}"
            new_line="${new_line/\%COOKIE_DOMAINS\%/${COOKIE_DOMAINS}}"
            new_line="${new_line/\%WEB_AGENT_NAME\%/${WEB_AGENT_NAME}}"
            new_line="${new_line/\%SESAM_SERVER_URL\%/${SESAM_SERVER_URL}}"
            new_line="${new_line/\%SESAM_SERVER_URL_SSL\%/${SESAM_SERVER_URL_SSL}}"
						new_line="${new_line/\%PRIMARY_ALIAS\%/${PRIMARY_ALIAS}}"
            new_line="${new_line/\%PRIMARY_ALIAS_SUPPORT\%/${PRIMARY_ALIAS_SUPPORT}}"
            new_line="${new_line/\%REALM_NAME_SUPPORT\%/${REALM_NAME_SUPPORT}}"
            new_line="${new_line/\%EXTERNAL_APP_URL_SUPPORT\%/${EXTERNAL_APP_URL_SUPPORT}}"
            new_line="${new_line/\%EXTERNAL_APP_URL_SUPPORT_NON_SSL\%/${EXTERNAL_APP_URL_SUPPORT_NON_SSL}}"
            new_line="${new_line/\%WEB_AGENT_NAME_SUPPORT\%/${WEB_AGENT_NAME_SUPPORT}}"
            new_line="${new_line/\%VALID_GOTO_URLS\%/${VALID_GOTO_URLS}}"
            new_line="${new_line/\%OPENAM_CONFIG_DIR\%/${OPENAM_CONFIG_DIR}}"

            if [ ! -z "$new_line" -a "$new_line" != " " ]; then
                if [[ ${new_line:0:1} != *"#"* ]]; then
                    openam_ssoadm "$new_line"
                fi
            fi
        done < "$script"
	done
}

##############################################################################
# Execute ssoadm command
##############################################################################

function openam_ssoadm() {
	local credentials="-u amadmin -f $openam_admin_psw_file"
    local command="$1"
	echo "${ssoadm_bin} ${command} ${credentials}"
    eval ${ssoadm_bin} ${command} ${credentials}
}

##############################################################################
# Restart OpenAM
##############################################################################

function openam_restart() {
	tomcat_restart
    checkrc
}

##############################################################################
# Test OpenAM availability
##############################################################################

function openam_test() {
	echo "*** Testing OpenAM Server availability..."
	openam_ssoadm list-servers
}

##############################################################################
# Check return code
##############################################################################

function checkrc() {
    if [ $? -ne 0 ]; then
        echo "ERROR: return code not success"
        exit
    fi
}
