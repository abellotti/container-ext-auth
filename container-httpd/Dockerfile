FROM bdunne/apache:latest
MAINTAINER ManageIQ https://github.com/ManageIQ/manageiq-appliance-build

## Atomic/OpenShift Labels
LABEL name="manageiq-apache" \
      vendor="ManageIQ" \
      version="2.4.6-45" \
      url="http://manageiq.org/" \
      summary="ManageIQ appliance apache image" \
      description="ManageIQ is a management and automation platform for virtual, private, and hybrid cloud infrastructures." \
      io.k8s.display-name="ManageIQ Apache" \
      io.k8s.description="ManageIQ Apache is the front-end for the ManageIQ Appliance." \
      io.openshift.expose-services="443:https" \
      io.openshift.tags="ManageIQ-Apache,apache"

## Set ENV
ENV HTTPD_AUTH_API_PORT=4100

## Install External-Authentication Required Packages
RUN yum -y install --setopt=tsflags=nodocs \
                   adcli                   \
                   c-ares                  \
                   certmonger              \
                   ipa-client              \
                   ipa-admintools          \
                   mod_auth_kerb           \
                   mod_authnz_pam          \
                   mod_intercept_form_submit \
                   mod_lookup_identity     \
                   mod_auth_mellon         \
                   oddjob                  \
                   oddjob-mkhomedir        \
                   realmd                  \
                   real-md                 \
                   sssd                    \
                   sssd-dbus               \
                   samba-common            \
                   &&                      \
    yum clean all

## Change workdir to application root, build/install gems
WORKDIR ${APP_ROOT}

COPY docker-assets/appliance-initialize.sh /bin
COPY docker-assets/container-scripts ${CONTAINER_SCRIPTS_ROOT}

## Build Auth-API
RUN mkdir /tmp/auth-api
COPY docker-assets/auth-api /tmp/auth-api
RUN (cd /tmp/auth-api && \
     cp crystal.repo /etc/yum.repos.d/crystal.repo && \
     rpm --import https://dist.crystal-lang.org/rpm/RPM-GPG-KEY && \
     yum install crystal -y && \
     shards install && \
     crystal build --release src/auth-api.cr && \
     cp auth-api /usr/bin/auth-api && \
     chmod 755 /usr/bin/auth-api && \
     rpm -e crystal && \
     rm -f /etc/yum.repos.d/crystal.repo && \
     cp auth-api.service /usr/lib/systemd/system/auth-api.service)

RUN systemctl enable dbus httpd auth-api

VOLUME [ "/sys/fs/cgroup" ]

ENTRYPOINT [ "entrypoint" ]
CMD [ "/usr/sbin/init" ]

