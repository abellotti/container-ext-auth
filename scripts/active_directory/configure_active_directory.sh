AD_IPADDR="10.8.96.173"
AD_SERVER="joev-ad-server.cloudforms.lab.eng.rdu2.redhat.com"
AD_DOMAIN="joev-ad.cloudforms.lab.eng.rdu2.redhat.com"
AD_ADMIN="Administrator"
AD_PASSWORD="smartvm"

SSSD_CONF="/etc/sssd/sssd.conf"
KERBEROS_KEYTAB_FILE="/etc/krb5.keytab"
KERBEROS_CONFIG_FILE="/etc/krb5.conf"
MIQ_EXTAUTH="/etc/httpd/conf.d/manageiq-external-auth.conf"

if [ -z "${APPLICATION_DOMAIN}" ]
then
  APPLICATION_DOMAIN="ext-auth-rearch.aabtest.redhat.com"
  # echo "ManageIQ Application Domain is not configured"
  # exit 1
fi

if [ -f $SSSD_CONF ]
then
  echo "External Authentication is already configured"
  exit 1
fi

if [ "$(hostname)" != ${APPLICATION_DOMAIN} ]
then
  echo "Configuring hostname to $APPLICATION_DOMAIN ..."
  hostname $APPLICATION_DOMAIN
fi

if [ -z "$(grep $AD_IPADDR /etc/hosts)" ]
then
  echo "Appending AD domain server in /etc/hosts"
  echo "$AD_IPADDR $AD_DOMAIN" >> /etc/hosts
fi

echo "Joining the AD Realm ..."
echo "$AD_PASSWORD" | realm join $AD_DOMAIN -U $AD_ADMIN
# option2 to be tested:
#   echo "$AD_PASSWORD" > /etc/sssd/realm-join-password
#   realm join $AD_DOMAIN -U $AD_ADMIN

echo "Allowing AD Users to Login ..."
realm permit --all

echo "Configuring PAM ..."
cp $APPLIANCE_TEMPLATE_DIRECTORY/etc/pam.d/httpd-auth /etc/pam.d/httpd-auth

chown apache $KERBEROS_KEYTAB_FILE
chmod 600 $KERBEROS_KEYTAB_FILE

echo "Configuring External HTTP ..."
cp $APPLIANCE_TEMPLATE_DIRECTORY/etc/httpd/conf.d/manageiq-remote-user.conf /etc/httpd/conf.d/
cp $APPLIANCE_TEMPLATE_DIRECTORY/etc/httpd/conf.d/manageiq-external-auth.conf.erb $MIQ_EXTAUTH
sed -i "s/<%= realm %>/${AD_DOMAIN}/" $MIQ_EXTAUTH
sed -i "s:/etc/http.keytab:${KERBEROS_KEYTAB_FILE}:" $MIQ_EXTAUTH
sed -i "s:Krb5KeyTab:KrbServiceName     Any\n  Krb5KeyTab:" $MIQ_EXTAUTH

echo "Updating $SSSD_CONF ..."
if [ -f /root/active_directory/sssd.conf ]
then
  cp /root/active_directory/sssd.conf $SSSD_CONF
fi

echo "Updating $KERBEROS_CONFIG_FILE ..."
if [ -f /root/active_directory/krb5.conf ]
then
  cp /root/active_directory/krb5.conf $KERBEROS_CONFIG_FILE
fi


echo -n "Save Configuration (y/n) ?"
read a

if [ "${a}" = "y" ]
then
  PERSISTENT_AUTH_CONFIG="/persistent/config"
  PERSISTENT_AUTH_TYPE="${PERSISTENT_AUTH_CONFIG}/auth_type"
  PERSISTENT_AUTH_FILES="${PERSISTENT_AUTH_CONFIG}/files"
  echo "Saving IPA Config to ${PERSISTENT_AUTH_FILES} ..."
  echo "ad" > ${PERSISTENT_AUTH_TYPE}
  rm -rf "${PERSISTENT_AUTH_FILES}"

  mkdir -p "${PERSISTENT_AUTH_FILES}${HTTPD_CONFIG_DIR}"
  cp ${HTTPD_CONFIG_DIR}/manageiq-remote-user.conf ${PERSISTENT_AUTH_FILES}${HTTPD_CONFIG_DIR}
  cp ${HTTPD_CONFIG_DIR}/manageiq-external-auth.conf ${PERSISTENT_AUTH_FILES}${HTTPD_CONFIG_DIR}

  mkdir -p "${PERSISTENT_AUTH_FILES}/etc"
  cp -p ${KERBEROS_KEYTAB_FILE} ${PERSISTENT_AUTH_FILES}${KERBEROS_KEYTAB_FILE}
  cp -p ${KERBEROS_CONFIG_FILE} ${PERSISTENT_AUTH_FILES}${KERBEROS_CONFIG_FILE}

  IPA_ALL_FILES="/etc/krb5.keytab
/etc/pam.d/httpd-auth
/etc/pam.d/smartcard-auth-ac
/etc/pam.d/fingerprint-auth-ac
/etc/pam.d/password-auth-ac
/etc/pam.d/postlogin-ac
/etc/pam.d/system-auth-ac
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

  ALL_FILES="/etc/pam.d/httpd-auth
/etc/pam.d/smartcard-auth-ac
/etc/pam.d/fingerprint-auth-ac
/etc/pam.d/password-auth-ac
/etc/pam.d/postlogin-ac
/etc/pam.d/system-auth-ac
/etc/sysconfig/network
/etc/sysconfig/authconfig
/etc/ssh/ssh_config
/etc/openldap/ldap.conf
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

