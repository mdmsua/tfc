FROM alpine:latest AS base

ARG VERSION=4.21.0

WORKDIR /tmp

ADD https://github.com/coreruleset/coreruleset/releases/download/v${VERSION}/coreruleset-${VERSION}-minimal.tar.gz coreruleset.tar.gz

RUN tar -xzf coreruleset.tar.gz
RUN mv coreruleset-${VERSION}/rules /tmp
RUN mv coreruleset-${VERSION}/crs-setup.conf.example /tmp/rules/crs-setup.conf
RUN rm coreruleset.tar.gz
RUN rm -r coreruleset-${VERSION}

ADD https://raw.githubusercontent.com/owasp-modsecurity/ModSecurity/v3/master/unicode.mapping /tmp/rules/unicode.mapping
ADD https://raw.githubusercontent.com/owasp-modsecurity/ModSecurity/v3/master/modsecurity.conf-recommended /tmp/rules/modsecurity.conf

FROM dhi.io/kubectl:1.34

COPY --chown=nonroot:nonroot --from=base /tmp/rules /home/nonroot/rules