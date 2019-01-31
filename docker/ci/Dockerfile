# Image to be used by GitLab CI

FROM docker.io/appuio/oc:v3.9

ENV HELM_HOME=/helm

COPY google-cloud-sdk.repo /etc/yum.repos.d/google-cloud-sdk.repo

RUN yum install -y \
    google-cloud-sdk \
    wget

RUN set -x \
 && helm init --client-only \
 && helm plugin install https://github.com/chartmuseum/helm-push \
 && chmod -R g+rwX "${HELM_HOME}" \
 && git version \
 && helm version --client \
 && helm plugin list
