#!/bin/sh

# Source OpenShift scripting env
[[ -s ${CONTAINER_SCRIPTS_ROOT}/container-deploy-common.sh ]] && source "${CONTAINER_SCRIPTS_ROOT}/container-deploy-common.sh"

# Prepare initialization environment
prepare_init_env

# Create log directory and symlink from app
setup_logs

# Create Apache certs directory and symlink from app and create certificates if not there
generate_server_certificates

# Initialize External-Authentication
[[ -x ${CONTAINER_SCRIPTS_ROOT}/initialize-external-authentication ]] && ${CONTAINER_SCRIPTS_ROOT}/initialize-external-authentication
