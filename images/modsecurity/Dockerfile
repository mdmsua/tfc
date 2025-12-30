FROM alpine:latest AS base

ARG VERSION=4.21.0

WORKDIR /tmp

ADD https://github.com/coreruleset/coreruleset/releases/download/v${VERSION}/coreruleset-${VERSION}-minimal.tar.gz coreruleset.tar.gz

RUN <<EOF
    tar -xzf coreruleset.tar.gz
    mv coreruleset-${VERSION}/rules /tmp
    mv coreruleset-${VERSION}/crs-setup.conf.example /tmp/rules/crs-setup.conf
    rm coreruleset.tar.gz
    rm -r coreruleset-${VERSION}
EOF

ADD https://raw.githubusercontent.com/owasp-modsecurity/ModSecurity/v3/master/unicode.mapping /tmp/rules/unicode.mapping
ADD https://raw.githubusercontent.com/owasp-modsecurity/ModSecurity/v3/master/modsecurity.conf-recommended /tmp/rules/modsecurity.conf

RUN sed -i 's/^SecRuleEngine DetectionOnly$/SecRuleEngine On/' /tmp/rules/modsecurity.conf

FROM dhi.io/kubectl:1.34

COPY --chown=nonroot:nonroot --from=base /tmp/rules /home/nonroot/rules