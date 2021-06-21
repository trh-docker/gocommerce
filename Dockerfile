# Build image
FROM quay.io/spivegin/gitonly:latest AS git

FROM quay.io/spivegin/golang:v1.13 AS builder
WORKDIR /opt/src/src/sc.tpnfc.us/proxyips/api
ADD . /opt/src/src/sc.tpnfc.us/proxyips/api

RUN ssh-keygen -t rsa -N "" -f ~/.ssh/id_rsa && git config --global user.name "quadtone" && git config --global user.email "quadtone@txtsme.com"
COPY --from=git /root/.ssh /root/.ssh
RUN ssh-keyscan -H github.com > ~/.ssh/known_hosts &&\
    ssh-keyscan -H gitlab.com >> ~/.ssh/known_hosts &&\
    ssh-keyscan -H gitea.com >> ~/.ssh/know_hosts

ENV deploy=c1f18aefcb3d1074d5166520dbf4ac8d2e85bf41 \
    GO111MODULE=on \
    GOPROXY=direct \
    GOSUMDB=off \
    GOPRIVATE=sc.tpnfc.us

RUN git config --global url.git@github.com:.insteadOf https://github.com/ &&\
    git config --global url.git@gitlab.com:.insteadOf https://gitlab.com/ &&\
    git config --global url.git@gitea.com:.insteadOf https://gitea.com/ &&\
    git config --global url."https://${deploy}@sc.tpnfc.us/".insteadOf "https://sc.tpnfc.us/"
RUN apt update && apt install build-essential -y

RUN git clone https://github.com/netlify/gocommerce.git &&\
    cd gocommerce &&\
    make deps build_linux &&\
    mv gocommerce /bin/

FROM quay.io/spivegin/tlmbasedebian
RUN mkdir /opt/bin
ENV DINIT=1.2.2 
COPY --from=builder /bin/gocommerce /opt/bin/gocommerce
ADD https://github.com/Yelp/dumb-init/releases/download/v${DINIT}/dumb-init_${DINIT}_amd64.deb /tmp/dumb-init_amd64.deb
ADD https://raw.githubusercontent.com/adbegon/pub/master/AdfreeZoneSSL.crt /usr/local/share/ca-certificates/
RUN chmod +x /opt/bin/gocommerce && ln -s /opt/bin/api /bin/gocommerce
RUN apt update && apt upgrade -y &&\
    apt install -y lsof curl nano &&\
    update-ca-certificates --verbose &&\
    dpkg -i /tmp/dumb-init_amd64.deb && \
    apt-get autoremove && apt-get autoclean &&\
    rm -rf /tmp/* /var/lib/apt/lists/* /var/tmp/*

EXPOSE 8080
ENTRYPOINT ["/usr/bin/dumb-init", "--"]
CMD ["gocommerce"]