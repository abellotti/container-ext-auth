# IDP_SERVER="aab-idp.aabsaml.redhat.com"
# IDP_IPADDR="10.8.97.7"
IDP_SERVER="aab-keycloak.aabsaml.redhat.com"
IDP_IPADDR="172.16.30.133"
IDP_REALM="miq"

MIQ_SAML_CONFIG="/root/saml/saml2"
SAML2_CONFIG_DIR="/etc/httpd/saml2"
HTTPD_CONFIG_DIR="/etc/httpd/conf.d/"

if [ -z "${APPLICATION_DOMAIN}" ]
then
  APPLICATION_DOMAIN="ext-auth-rearch.aabtest.redhat.com"
  # echo "ManageIQ Application Domain is not configured"
  # exit 1
fi

if [ -d $SAML2_CONFIG_DIR ]
then
  echo "SAML is already configured"
  exit 1
fi

if [ $(hostname) != ${APPLICATION_DOMAIN} ]
then
  echo "Configuring hostname to $APPLICATION_DOMAIN ..."
  hostname $APPLICATION_DOMAIN
fi

export HOST=$APPLICATION_DOMAIN
export HOST_DOMAIN=`echo $APPLICATION_DOMAIN | cut -f2- -d.`
export HOST_REALM=`echo $HOST_DOMAIN | tr '[a-z]' '[A-Z]'`

if [ -z "$(grep $IDP_IPADDR /etc/hosts)" ]
then
  echo "Appending SAML IDP server to /etc/hosts"
  echo "$IDP_IPADDR $IDP_SERVER" >> /etc/hosts
fi

echo "Creating $SAML2_CONFIG_DIR ..."
mkdir -p $SAML2_CONFIG_DIR

echo "Configuring External HTTP ..."
cp $APPLIANCE_TEMPLATE_DIRECTORY/etc/httpd/conf.d/manageiq-remote-user.conf $HTTPD_CONFIG_DIR
cp $APPLIANCE_TEMPLATE_DIRECTORY/etc/httpd/conf.d/manageiq-external-auth-saml.conf $HTTPD_CONFIG_DIR

echo "Creating SAML2 configuration data ..."
cd $SAML2_CONFIG_DIR
if [ -f ${MIQ_SAML_CONFIG}/miqsp-metadata.xml ]
then
  echo "Copying in MiQ SP configuration files ..."
  cp ${MIQ_SAML_CONFIG}/miqsp-key.key .
  cp ${MIQ_SAML_CONFIG}/miqsp-cert.cert .
  cp ${MIQ_SAML_CONFIG}/miqsp-metadata.xml .
else
  echo "Creating MiQ SP configuration files ..."
  /usr/libexec/mod_auth_mellon/mellon_create_metadata.sh https://${APPLICATION_DOMAIN} https://${APPLICATION_DOMAIN}/saml2
  mv https_*.key  miqsp-key.key
  mv https_*.cert miqsp-cert.cert
  mv https_*.xml  miqsp-metadata.xml
fi

cd $SAML2_CONFIG_DIR
if [ -f ${MIQ_SAML_CONFIG}/idp-metadata.xml ]
then
  echo "Copying in idp-metadata.xml ..."
  cp ${MIQ_SAML_CONFIG}/idp-metadata.xml .
else
  echo "Pulling in idp-metadata.xml ..."
  curl -s -o idp-metadata.xml http://${IDP_HOST}:8080/auth/realms/${IDP_REALM}/protocol/saml/descriptor
fi

echo -n "Save Configuration (y/n) ?"
read a

if [ "${a}" = "y" ]
then
  PERSISTENT_AUTH_CONFIG="/persistent/config"
  PERSISTENT_AUTH_FILES="${PERSISTENT_AUTH_CONFIG}/files"
  PERSISTENT_AUTH_TYPE="${PERSISTENT_AUTH_CONFIG}/auth_type"
  echo "Saving SAML Config to ${PERSISTENT_AUTH_FILES} ..."
  echo "saml" > ${PERSISTENT_AUTH_TYPE}
  rm -rf "${PERSISTENT_AUTH_FILES}"

  mkdir -p ${PERSISTENT_AUTH_FILES}${SAML2_CONFIG_DIR}
  cp ${SAML2_CONFIG_DIR}/* ${PERSISTENT_AUTH_FILES}${SAML2_CONFIG_DIR}

  mkdir -p "${PERSISTENT_AUTH_FILES}${HTTPD_CONFIG_DIR}"
  cp ${HTTPD_CONFIG_DIR}/manageiq-remote-user.conf ${PERSISTENT_AUTH_FILES}${HTTPD_CONFIG_DIR}
  cp ${HTTPD_CONFIG_DIR}/manageiq-external-auth-saml.conf ${PERSISTENT_AUTH_FILES}${HTTPD_CONFIG_DIR}
fi

echo "Restarting HTTPD ..."
systemctl restart httpd

