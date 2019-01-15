#!/usr/bin/env bash

###################################################################################
# Deployment script that can be used for CI automation, etc.
# This script assumes that kubectl and helm are available, and have been configured
# with the correct context for the cluster.
# Warning:
#   - This script will purge any existig deployments in the target namespace!
#   - This script is not supported by Forgerock
#
# Usage:
#   - You must provide folder that contains env.sh script that contains:
#       - NAMESPACE, COMPONENTS vars
#   - You may provide yaml files for each component. Values in these files will
#     override default values for helm charts
#   - For examples look into: forgeops/samples/config/
#
#
####################################################################################

setup_kubectl()
{
#    curl -L -o /usr/bin/kubectl "https://storage.googleapis.com/kubernetes-release/release/v${KUBERNETES_VERSION}/bin/linux/amd64/kubectl"
#    chmod +x /usr/bin/kubectl
    kubectl version --client
}

setup_helm()
{
    echo "=> Installing and configuring helm, tiller & a helm repo..."

#    curl "https://kubernetes-helm.storage.googleapis.com/helm-v${HELM_VERSION}-linux-amd64.tar.gz" | tar zx
#    mv linux-amd64/helm /usr/bin/
#    mv linux-amd64/tiller /usr/bin/
#    rm -rf linux-amd64
    helm version --client
#    tiller -version
    helm init --client-only
    helm repo add sws-chartmuseum $HELM_REPO_URL --username $HELM_REPO_USERNAME --password $HELM_REPO_PASSWORD
    helm repo update
    oc -n ${NAMESPACE} policy add-role-to-user edit "system:serviceaccount:${TILLER_NAMESPACE}:tiller"
}

chk_config()
{
    export CFGDIR="config/$FORGEOPS_CONFIG"

    if [ -z "${CFGDIR}" ] || [ ! -d "${CFGDIR}" ]; then
        echo "ERROR: Configuration directory path $CFGDIR not given or inaccessable.  Exiting!"
        exit 1
    else
        echo "=> Using \"${CFGDIR}\" as the root of your configuration"

        echo "=> Substituting environment variables in $CFGDIR files"
        # we need a tmp directory with the substituted files
        DEPLOYDIR=/tmp/deploy
        mkdir -p $DEPLOYDIR
        # first substitute vars in yaml files
        for FILE in $CFGDIR/*.yaml; do
            envsubst < $FILE > $DEPLOYDIR/$(basename $FILE)
        done
        # copy substituted yaml files back to CFGDIR, replacing the original yaml files
        cp -rp $DEPLOYDIR/* $CFGDIR
        # remove tmp folder
        rm -rf $DEPLOYDIR

        if [ -r  ${CFGDIR}/env.sh ]; then
            echo "=> Reading ${CFGDIR}/env.sh"
            source ${CFGDIR}/env.sh
        fi
        # We want env.sh provided on the command line to take precedence.
        if [ ! -z "${ENV_SH}" ]; then
            echo "=> Reading ${ENV_SH}"
            source "${ENV_SH}"
        fi
    fi

    if [ -z "${NAMESPACE}" ]; then
        echo "ERROR: Your Namespace is not set for the deployment. Exiting!"
        exit 1
    fi
    echo -e "=>\tNamespace: \"${NAMESPACE}\""

    CONTEXT=$(kubectl config current-context)
    if [ $? != 0 ]; then
        echo "ERROR: Your k8s Context is not set. Please set it before running this script. Exiting!"
        exit 1
    fi
    echo "=> k8s Context is: \"${CONTEXT}\""

    #if [ "${CONTEXT}" = "minikube" ]; then
    #    echo "=> Minikube deployment detected.  Installing tiller..."
    #    helm init --service-account default --upgrade
    #    echo "=> Giving tiller few seconds to get ready..."
    #    sleep 30s
    #fi

    if [ -z "${COMPONENTS}" ]; then
        COMPONENTS=(frconfig configstore userstore ctsstore openam amster)
    fi
    echo -e "=>\tComponents: \"${COMPONENTS[*]}\""

    AM_URL="${EXTERNAL_FQDN}"
}

remove_all()
{
    if [ "${RMALL}" = "yes" ]; then
        echo "=> Removing all components of the deployment from ${NAMESPACE}"
        ./bin/remove-all.sh ${NAMESPACE}
    fi
}

project_exists()
{
    echo "=> Checking project \"${NAMESPACE}\""
    RESULT=$( curl -s https://control.vshn.net/api/openshift/1/appuio%20public/projects/${NAMESPACE}?accessToken=${APPUIO_API_TOKEN} )
    #echo "RESULT = $RESULT"
    if [ "$RESULT" == "OpenShift project not found" ]; then
      return 1
    else
      return 0
    fi

}

create_project()
{
    if $(kubectl get namespace ${NAMESPACE} > /dev/null 2>&1); then
        echo "=> Namespace ${NAMESPACE} already exists.  Skipping creation..."
    else
        echo "=> Creating project \"${NAMESPACE}\""
        curl -s -X POST https://control.vshn.net/api/openshift/1/appuio%20public/projects/?accessToken=${APPUIO_API_TOKEN} -d "{\"name\":\"${NAMESPACE}\", \"adminUids\":[\"system:serviceaccount:${GITLAB_NAMESPACE}:gitlab\",\"sws-tfelner1\"], \"editorUids\":[\"system:serviceaccount:${TILLER_NAMESPACE}:tiller\"], \"productId\":\"dedicated:v1\", \"customerId\":\"swisssign\"}"
        if [ $? -ne 0 ]; then
            echo "Non-zero return by curl. Is your context correct? Exiting!"
            exit 1
        fi
        while ! project_exists; do
          echo "Waiting for project ${NAMESPACE} to be created"
          sleep 1
        done
    fi
}

delete_project()
{
    echo "=> Deleting project ${NAMESPACE}"
    while project_exists; do
      curl -s -X DELETE https://control.vshn.net/api/openshift/1/appuio%20public/projects/${NAMESPACE}?accessToken=${APPUIO_API_TOKEN}
      echo "Waiting for project ${NAMESPACE} to be deleted"
      sleep 5
    done
}

create_image_pull_secret()
{
    echo "=> Creating image pull secret..."
    kubectl create secret -n "${NAMESPACE}" \
      docker-registry gitlab-registry \
      --docker-server="$CI_REGISTRY" \
      --docker-username="${CI_DEPLOY_USER:-$CI_REGISTRY_USER}" \
      --docker-password="${CI_DEPLOY_PASSWORD:-$CI_REGISTRY_PASSWORD}" \
      --docker-email="operations.swissid@swisssign.com" \
      -o yaml --dry-run | kubectl replace -n "${NAMESPACE}" --force -f -

    echo "=> Configuring service account with image pull secret..."
    result=$(kubectl -n "${NAMESPACE}" patch serviceaccount default -p '{"imagePullSecrets": [{"name": "gitlab-registry"}]}')
    code="$?"
    if [[ "$code" != "0" && "$result" == *" not patched" ]]; then
        echo "$result" 1>&2
        exit "$code"
    fi
}

deploy_charts()
{
    echo "=> Deploying charts into namespace \"${NAMESPACE}\" with URL \"${AM_URL}\""

    # If the deploy directory contains a common.yaml, prepend it to the helm arguments.
    if [ -r "${CFGDIR}"/common.yaml ]; then
        YAML="-f ${CFGDIR}/common.yaml $YAML"
    fi

    # These are the charts (components) that will be deployed via helm
    for comp in ${COMPONENTS[@]}; do
        chart="${comp}"
        case "${comp}" in
          *store)
            chart="ds"
            ;;
        esac

        CHART_YAML=""
        if [ -r  "${CFGDIR}/${comp}.yaml" ]; then
           CHART_YAML="-f ${CFGDIR}/${comp}.yaml"
        fi

        ${DRYRUN} helm upgrade -i ${NAMESPACE}-${comp} \
            ${YAML} ${CHART_YAML} \
            --namespace=${NAMESPACE} sws-chartmuseum/${chart}
    done
}

import_check()
{
    # This live check waits for AM config to be imported.
    # We are looking at amster pod logs periodically.
    echo "=> Live check - waiting for config to be imported to AM";
    sleep 10
    FINISHED_STRING="Configuration script finished"

    while true; do
        AMSTER_POD_NAME=$(kubectl -n=${NAMESPACE} get pods --selector=component=amster \
          -o jsonpath='{.items[*].metadata.name}')
        echo "Inspecting amster pod: ${AMSTER_POD_NAME}"
        OUTPUT=$(kubectl -n=${NAMESPACE} logs ${AMSTER_POD_NAME} amster || true)
        if [[ "$OUTPUT" = *$FINISHED_STRING* ]]; then
            echo "=> AM configuration import is finished"
            break
        fi
        echo "=> Configuration not finished yet. Waiting for 10 seconds...."
        sleep 10
    done
}

isalive_check()
{
    PROTO="https"
    ALIVE_JSP="${PROTO}://${AM_URL}/isAlive.jsp"
    echo "=> Testing ${ALIVE_JSP}"
    STATUS_CODE="503"
    until [ "${STATUS_CODE}" = "200" ]; do
        echo "   ${ALIVE_JSP} is not alive, waiting 10 seconds before retry..."
        sleep 10
        STATUS_CODE=$(curl --connect-timeout 5 -k -LI  ${ALIVE_JSP} -o /dev/null -w '%{http_code}\n' -sS | grep -v libCVP11LCB || true)
    done
    echo "=> AM is alive"
}

restart_am()
{
    OPENAM_POD_NAME=$(kubectl -n=${NAMESPACE} get pods --selector=app=openam \
        -o jsonpath='{.items[*].metadata.name}')
    echo "=> Deleting \"${OPENAM_POD_NAME}\" to restart and read newly imported configuration"
    kubectl delete pod $OPENAM_POD_NAME --namespace=${NAMESPACE}
    if [ $? -ne 0 ]; then
        echo "Could not delete AM pod.  Please check error and fix."
    fi
    sleep 10
    isalive_check
}

scale_am()
{
    echo "=> Scaling AM deployment..."
    DEPNAME=$(kubectl get deployment -l app=openam -o name)
    kubectl scale --replicas=${OPENAM_REPLICAS} ${DEPNAME} || true
    if [ $? -ne 0 ]; then
        echo "Could not scale AM deployment.  Please check error and fix."
    fi
}

deploy_hpa()
{
    echo "=> Deploying Horizontal Autoscale Chart..."
    kubectl apply -f ${DEPLOYDIR}/hpa.yaml || true
    if [ $? -ne 0 ]; then
        echo "Could not deploy HPA.  Please check error and fix."
    fi
}
