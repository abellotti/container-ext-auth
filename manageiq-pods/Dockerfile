FROM bdunne/slim:latest
MAINTAINER ManageIQ https://github.com/ManageIQ/manageiq-appliance-build

## Atomic/OpenShift Labels
LABEL name="manageiq" \
      vendor="ManageIQ" \
      version="Master" \
      release="master" \
      url="http://manageiq.org/" \
      summary="ManageIQ appliance image" \
      description="ManageIQ is a management and automation platform for virtual, private, and hybrid cloud infrastructures." \
      io.k8s.display-name="ManageIQ" \
      io.k8s.description="ManageIQ is a management and automation platform for virtual, private, and hybrid cloud infrastructures." \
      io.openshift.expose-services="443:https" \
      io.openshift.tags="ManageIQ,miq,manageiq"

## Set ENV
ENV HTTPD_AUTH_API_PORT=4100

## Change workdir to application root, build/install gems
WORKDIR ${APP_ROOT}

COPY docker-assets/httpd_container_auth_api.rb /var/www/miq/vmdb/config/initializers/

ENTRYPOINT [ "/usr/local/bin/dumb-init", "--single-child", "--"]
CMD [ "entrypoint" ]

