# Environment settings for the deployment
# Using shell parameter expansion to parse the yaml file

# remove any leading spaces
while read line
do
    if [[ "$line" =~ ^domain:.*$ ]]; then
    	DOMAIN=${line#domain:}
    	DOMAIN=${DOMAIN// /}
    fi
done < $CFGDIR/common.yaml

# k8s namespace to deploy in
#NAMESPACE="foobar"

# Top level domain. Do not include the leading "."
# You can override by just providing a string here
DOMAIN="${DOMAIN/\./}"

# The components to deploy
# Note the opendj stores are aliased as configstore,
# userstore, ctstore - but they all use the opendj chart
#COMPONENTS=(frconfig configstore userstore ctsstore openam amster)
