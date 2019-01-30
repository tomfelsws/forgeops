#!/usr/bin/env bash

# Helm client version to install
HELM_VERSION="2.12.2"

install_helm()
{
    echo "=> Installing helm & tiller ..."
    curl "https://kubernetes-helm.storage.googleapis.com/helm-v${HELM_VERSION}-linux-amd64.tar.gz" | tar zx
    mv linux-amd64/helm /usr/bin/
    mv linux-amd64/tiller /usr/bin/
    rm -rf linux-amd64
    helm version --client
    tiller -version
}

init_helm_client()
{
    echo "=> Configuring helm ..."
    helm init --client-only
}

add_helm_repo()
{
    echo "=> Adding a helm repo ..."
    helm repo add sws-chartmuseum $HELM_REPO_URL --username $HELM_REPO_USERNAME --password $HELM_REPO_PASSWORD
    helm repo update
}

# This function is currently not required as the required role is added in create_appuio_project()
# This may change once we have our own SwissSign Openshift cluster
add_tiller_role()
{
    echo "=> Add tiller edit role to OpenShift project $NAMESPACE ..."
    oc -n ${NAMESPACE} policy add-role-to-user edit "system:serviceaccount:${TILLER_NAMESPACE}:tiller"
}
