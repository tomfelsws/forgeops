# Environment settings for the deployment
# Using shell parameter expansion to parse the yaml file

# remove any leading spaces
while read line
do
    if [[ "$line" =~ ^fqdn:.*$ ]]; then
    	FQDN=${line#fqdn:}
    	FQDN=${FQDN// /}
    fi

    if [[ "$line" =~ ^domain:.*$ ]]; then
    	DOMAIN=${line#domain:}
    	DOMAIN=${DOMAIN// /}
    fi
done < $CFGDIR/common.yaml

# k8s namespace to deploy in
NAMESPACE="dev"

# Top level domain. Do not include the leading "."
# You can override by just providing a string here
DOMAIN="${DOMAIN/\./}"

# The components to deploy
# Note the opendj stores are aliased as configstore,
# userstore, ctstore - but they all use the opendj chart
COMPONENTS=(frconfig configstore userstore ctsstore openam amster)

# Docker registry to use
DOCKER_SERVER="registry.gitlab.com"
DOCKER_USERNAME="gitlab+deploy-token-37414"
DOCKER_PASSWORD="XsHwrHGZa8EDLb4LdkWR"
DOCKER_EMAIL="operations.swissid@swisssign.com"

OPENAM_REPLICAS=1
