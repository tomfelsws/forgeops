#!/usr/bin/env bash

# https://docs.gitlab.com/ee/user/project/clusters/#adding-an-existing-kubernetes-cluster

kubectl create -f - <<EOF
   apiVersion: v1
   kind: ServiceAccount
   metadata:
     name: gitlab
     namespace: default
EOF

kubectl create -f - <<EOF
 kind: ClusterRoleBinding
 apiVersion: rbac.authorization.k8s.io/v1
 metadata:
   name: gitlab-cluster-admin
 subjects:
 - kind: ServiceAccount
   name: gitlab
   namespace: default
 roleRef:
   kind: ClusterRole
   name: cluster-admin
   apiGroup: rbac.authorization.k8s.io
EOF
