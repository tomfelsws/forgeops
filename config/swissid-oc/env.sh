# Environment settings for the deployment
# Using shell parameter expansion to parse the yaml file

# Set the URL_PREFIX and DOMAIN from common.yaml and
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

# The URL prefix for openam service
# You can override by just providing a string here
URL_PREFIX="${FQDN%%.*}"

# k8s namespace to deploy in
#NAMESPACE="sws-tom1"

# Top level domain. Do not include the leading "."
# You can override by just providing a string here
DOMAIN="${DOMAIN/\./}"

# The components to deploy
# Note the opendj stores are aliased as configstore,
# userstore, ctstore - but they all use the opendj chart
#COMPONENTS=(frconfig configstore userstore ctsstore openam amster)

# Tiller Project
OC_TILLER_PROJECT="sws-tiller"

# Set tiller namespace for helm
#export TILLER_NAMESPACE=${OC_TILLER_PROJECT}

# Monitoring Project
OC_MONITORING_PROJECT="sws-monitoring"

# Openshift Project
OC_PROJECT="sws-tom1"

# Static (External) IP Address to assign to the Route
OC_ROUTE_IP="5.102.151.2"
