# Utility image 
# Copyright (c) 2016-2018 ForgeRock AS.
#
# Utility shell scripts used as init containers to perform creation of bootstrap files
# wait for for pods to be available, etc.
# We expect this to be deprecated for 6.5 
FROM alpine:3.8

#  -Dcom.iplanet.services.debug.level=error

ENV FORGEROCK_HOME /home/forgerock
ENV OPENAM_HOME /home/forgerock/openam

ENV KUBE_LATEST_VERSION=v1.13.0
ENV HELM_VERSION=v2.12.0

# Openshift Version 3.9.0
#ENV OS_CLI_VERSION=v3.9.0
#ENV OS_TAG=191fece

# Openshift Version 3.10.0
#ENV OS_CLI_VERSION=v3.10.0
#ENV OS_TAG=dd10d17

# Openshift Version 3.11.0
ENV OS_CLI_VERSION=v3.11.0
ENV OS_TAG=0cbc58b
ENV OC_FILE=openshift-origin-client-tools-${OS_CLI_VERSION}-${OS_TAG}-linux-64bit

RUN apk update \
    && apk upgrade \
    && apk add --update ca-certificates \
    && apk add --update -t deps curl\
    && curl -s -L https://storage.googleapis.com/kubernetes-release/release/${KUBE_LATEST_VERSION}/bin/linux/amd64/kubectl -o /usr/local/bin/kubectl \
    && curl -s -L https://github.com/openshift/origin/releases/download/${OS_CLI_VERSION}/${OC_FILE}.tar.gz | tar xz && mv ${OC_FILE}/oc /usr/local/bin/oc && rm -rf ${OC_FILE} \
    && curl -s -L https://storage.googleapis.com/kubernetes-helm/helm-${HELM_VERSION}-linux-amd64.tar.gz | tar xz && mv linux-amd64/helm /usr/local/bin/helm && rm -rf linux-amd64 /tmp/helm.tgz \
    && chmod +x /usr/local/bin/kubectl /usr/local/bin/helm \
    && ls -l /usr/local/bin/oc /usr/local/bin/helm /usr/local/bin/kubectl \
    && apk del --purge deps \
    && apk add --update jq su-exec unzip curl bash openldap-clients \
    && rm /var/cache/apk/* \
    && mkdir -p $FORGEROCK_HOME \
    && addgroup -g 11111 forgerock \
    && adduser -s /bin/bash -h "$FORGEROCK_HOME" -u 11111 -D -G forgerock forgerock \
    # Delete apk cache
    && rm -rf /var/cache/apk/*


# # openldap-clients is needed to test for the configuration store.
# RUN apk add --no-cache su-exec unzip curl bash openldap-clients \
#     && mkdir -p $FORGEROCK_HOME \
#     && addgroup -g 11111 forgerock \
#     && adduser -s /bin/bash -h "$FORGEROCK_HOME" -u 11111 -D -G forgerock forgerock

USER forgerock


COPY *.sh $FORGEROCK_HOME/

ENTRYPOINT ["/home/forgerock/docker-entrypoint.sh"]


CMD ["pause"]