FROM hashicorp/tfc-agent:latest

USER root

ARG KUBELOGIN_VERSION=0.2.12
ARG TARGETARCH

ADD https://github.com/Azure/kubelogin/releases/download/v${KUBELOGIN_VERSION}/kubelogin-linux-${TARGETARCH}.zip /tmp/kubelogin.zip

RUN apt-get install -y unzip && \
    unzip /tmp/kubelogin.zip -d /tmp && \
    mv /tmp/bin/linux_${TARGETARCH}/kubelogin /usr/local/bin/kubelogin && \
    chmod a+x /usr/local/bin/kubelogin && \
    rm /tmp/kubelogin.zip && \
    apt-get purge -y unzip && \
    apt-get clean

USER tfc-agent