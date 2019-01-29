# Image to be used by GitLab CI

FROM docker.io/appuio/oc:v3.9

COPY google-cloud-sdk.repo /etc/yum.repos.d/google-cloud-sdk.repo

RUN yum install -y google-cloud-sdk
