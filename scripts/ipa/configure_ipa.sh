IPA_IPADDR="172.16.30.222"
IPA_SERVER="aab-ipaserver7.aabtest.redhat.com"
IPA_PRINCIPAL="admin"
IPA_PASSWORD="smartvm1"
IPA_REALM="AABTEST.REDHAT.COM"
IPA_DOMAIN="AABTEST.REDHAT.COM"

IPA_CLIENT_INSTALL=/sbin/ipa-client-install
HTTPD_CONFIG_DIR=/etc/httpd/conf.d
PAM_CONFIG_DIR=/etc/pam.d
HTTP_KEYTAB=/etc/http.keytab
SSSD_CONFIG_DIR=/etc/sssd
SSSD_CONF="${SSSD_CONFIG_DIR}/sssd.conf"
KERBEROS_CONFIG_FILE=/etc/krb5.conf

if [ -z "${APPLICATION_DOMAIN}" ]
then
  APPLICATION_DOMAIN="ext-auth-rearch.aabtest.redhat.com"
  # echo "ManageIQ Application Domain is not configured"
  # exit 1
fi

if [ -f $SSSD_CONF ]
then
  if [ "${1}" != "-f" ]
  then
    echo "External Authentication is already configured"
    exit 1
  fi
  echo "External Authentication is already configured - Forcing an unconfiguration"
  $IPA_CLIENT_INSTALL --uninstall --unattended
fi

if [ "$(hostname)" != ${APPLICATION_DOMAIN} ]
then
  echo "Configuring hostname to $APPLICATION_DOMAIN ..."
  hostname $APPLICATION_DOMAIN
fi

export HOST=$APPLICATION_DOMAIN
export HOST_DOMAIN=`echo $APPLICATION_DOMAIN | cut -f2- -d.`
export HOST_REALM=`echo $HOST_DOMAIN | tr '[a-z]' '[A-Z]'`
export HTTP_IPA_SERVICE="HTTP/$HOST@$HOST_REALM"

if [ -z "$(grep $IPA_IPADDR /etc/hosts)" ]
then
  echo "Appending IPA server in /etc/hosts"
  echo "$IPA_IPADDR $IPA_SERVER" >> /etc/hosts
fi

echo "Enabling SSSD ..."
systemctl enable sssd

echo "Setting up IPA Client ..."
$IPA_CLIENT_INSTALL -N --force-join --fixed-primary --unattended --realm $IPA_REALM --domain $IPA_DOMAIN --server $IPA_SERVER --principal $IPA_PRINCIPAL --password $IPA_PASSWORD

echo "Configuring PAM ..."
cp $APPLIANCE_TEMPLATE_DIRECTORY${PAM_CONFIG_DIR}/httpd-auth ${PAM_CONFIG_DIR}/httpd-auth

echo "Configuring IPA HTTP Service ..."
/bin/echo $IPA_PASSWORD | /usr/bin/kinit $IPA_PRINCIPAL

if [ -z "$(/usr/bin/ipa -e skip_version_check=1 service-find $HTTP_IPA_SERVICE)" ]
then
  echo "Registering Service $HTTP_IPA_SERVICE ..."
  /usr/bin/ipa -e skip_version_check=1 service-add --force $HTTP_IPA_SERVICE
else
  echo "Service $HTTP_IPA_SERVICE exists ..."
fi

echo "Getting IPA Keytab $HTTP_KEYTAB for Service $HTTP_IPA_SERVICE ..."
/usr/sbin/ipa-getkeytab -s $IPA_SERVER -k $HTTP_KEYTAB -p $HTTP_IPA_SERVICE

chown apache $HTTP_KEYTAB
chmod 600 $HTTP_KEYTAB

echo "Backing up $KERBEROS_CONFIG_FILE ..."
cp ${KERBEROS_CONFIG_FILE} ${KERBEROS_CONFIG_FILE}.miqbkp

echo "Updating $KERBEROS_CONFIG_FILE ..."
sed -i 's/dns_lookup_kdc = false/dns_lookup_dkc = true/' $KERBEROS_CONFIG_FILE
sed -i 's/dns_lookup_realm = false/dns_lookup_realm = true/' $KERBEROS_CONFIG_FILE

echo "Configuring External HTTP ..."
cp $APPLIANCE_TEMPLATE_DIRECTORY${HTTPD_CONFIG_DIR}/manageiq-remote-user.conf ${HTTPD_CONFIG_DIR}
cp $APPLIANCE_TEMPLATE_DIRECTORY${HTTPD_CONFIG_DIR}/manageiq-external-auth.conf.erb ${HTTPD_CONFIG_DIR}/manageiq-external-auth.conf
sed -i "s/<%= realm %>/${HOST_DOMAIN}/" ${HTTPD_CONFIG_DIR}/manageiq-external-auth.conf

echo "Updating $SSSD_CONF ..."
cp /root/ipa/sssd.conf $SSSD_CONF

# echo "Set Timezone ..."
# mv /etc/localtime /etc/localtime.bak
# ln -s /usr/share/zoneinfo/America/New_York /etc/localtime

echo -n "Save Configuration (y/n) ?"
read a

if [ "${a}" = "y" ]
then
  PERSISTENT_AUTH_CONFIG="/persistent/config"
  PERSISTENT_AUTH_TYPE="${PERSISTENT_AUTH_CONFIG}/auth_type"
  PERSISTENT_AUTH_FILES="${PERSISTENT_AUTH_CONFIG}/files"
  echo "Saving IPA Config to ${PERSISTENT_AUTH_FILES} ..."
  echo "ipa" > ${PERSISTENT_AUTH_TYPE}
  rm -rf "${PERSISTENT_AUTH_FILES}"

  mkdir -p "${PERSISTENT_AUTH_FILES}${HTTPD_CONFIG_DIR}"
  cp ${HTTPD_CONFIG_DIR}/manageiq-remote-user.conf ${PERSISTENT_AUTH_FILES}${HTTPD_CONFIG_DIR}
  cp ${HTTPD_CONFIG_DIR}/manageiq-external-auth.conf ${PERSISTENT_AUTH_FILES}${HTTPD_CONFIG_DIR}

  mkdir -p "${PERSISTENT_AUTH_FILES}/etc"
  cp -p ${HTTP_KEYTAB} ${PERSISTENT_AUTH_FILES}/etc
  cp -p ${KERBEROS_CONFIG_FILE} ${PERSISTENT_AUTH_FILES}${KERBEROS_CONFIG_FILE}

  ALL_FILES="/etc/krb5.keytab
/etc/pam.d/httpd-auth
/etc/pam.d/smartcard-auth-ac
/etc/pam.d/fingerprint-auth-ac
/etc/pam.d/password-auth-ac
/etc/pam.d/postlogin-ac
/etc/pam.d/system-auth-ac
/etc/nsswitch.conf
/etc/sysconfig/network
/etc/sysconfig/authconfig
/etc/ssh/ssh_config
/etc/openldap/ldap.conf
/etc/ipa/nssdb/cert8.db
/etc/ipa/nssdb/key3.db
/etc/ipa/nssdb/secmod.db
/etc/ipa/nssdb/pwdfile.txt
/etc/ipa/default.conf
/etc/ipa/ca.crt
/etc/pki/ca-trust/source/ipa.p11-kit
/etc/sssd/sssd.conf"

  for FILE in $ALL_FILES
  do
    echo "Backing up $FILE ..."
    BASE_DIR="`dirname $FILE`"
    mkdir -p "${PERSISTENT_AUTH_FILES}${BASE_DIR}"
    cp -p $FILE "${PERSISTENT_AUTH_FILES}${FILE}"
  done
fi

echo "Restarting SSSD and HTTPD ..."
systemctl restart sssd
systemctl restart httpd

