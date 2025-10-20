FROM hashicorp/tfc-agent:latest

USER root

ARG KUBELOGIN_VERSION=0.2.12

ADD https://github.com/Azure/kubelogin/releases/download/v${KUBELOGIN_VERSION}/kubelogin-linux-amd64.zip /tmp/kubelogin.zip

RUN apt-get install -y unzip && \
    unzip /tmp/kubelogin.zip -d /tmp && \
    mv /tmp/bin/linux_amd64/kubelogin /usr/local/bin/kubelogin && \
    chmod a+x /usr/local/bin/kubelogin && \
    rm /tmp/kubelogin.zip && \
    apt-get purge -y unzip && \
    apt-get clean

USER tfc-agent