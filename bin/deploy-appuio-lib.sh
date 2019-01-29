#!/usr/bin/env bash

appuio_project_exists()
{
    echo "=> Checking APPUiO project \"${NAMESPACE}\""
    #oc get project "${NAMESPACE}"
    #return $?
    RESULT=$( curl -s https://control.vshn.net/api/openshift/1/appuio%20public/projects/${NAMESPACE}?accessToken=${APPUIO_API_TOKEN} )
    #echo "RESULT = $RESULT"
    if [ "$RESULT" == "OpenShift project not found" ]; then
      return 1
    else
      return 0
    fi
}

create_appuio_project()
{
    if $(kubectl get namespace ${NAMESPACE} > /dev/null 2>&1); then
        echo "=> APPUiO project \"${NAMESPACE}\" already exists. Skipping creation..."
    else
        echo "=> Creating APPUiO project \"${NAMESPACE}\""
        curl -s -X POST https://control.vshn.net/api/openshift/1/appuio%20public/projects/?accessToken=${APPUIO_API_TOKEN} -d "{\"name\":\"${NAMESPACE}\", \"adminUids\":[\"system:serviceaccount:${GITLAB_NAMESPACE}:gitlab\"], \"adminGids\":[\"Cust SwissSign\"],\"editorUids\":[\"system:serviceaccount:${TILLER_NAMESPACE}:tiller\"], \"productId\":\"dedicated:v1\", \"customerId\":\"swisssign\"}"
        if [ $? -ne 0 ]; then
            echo "Non-zero return by curl. Is your context correct? Exiting!"
            exit 1
        fi
        while ! appuio_project_exists; do
          echo "Waiting for APPUiO project ${NAMESPACE} to be created"
          sleep 1
        done
    fi
}

delete_appuio_project()
{
    echo "=> Deleting APPUiO project ${NAMESPACE}"
    curl -s -X DELETE https://control.vshn.net/api/openshift/1/appuio%20public/projects/${NAMESPACE}?accessToken=${APPUIO_API_TOKEN}
      while appuio_project_exists; do
      echo "Waiting for APPUiO project ${NAMESPACE} to be deleted"
      sleep 5
    done
}
