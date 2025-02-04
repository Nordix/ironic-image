#!/usr/bin/bash

set -euxo pipefail

export IRONIC_REVERSE_PROXY_SETUP=${IRONIC_REVERSE_PROXY_SETUP:-false}

# CUSTOM_CONFIG_DIR is also managed in the ironic-common.sh, in order to
# keep auth-common and ironic-common separate (to stay consistent with the
# architecture) part of the ironic-common logic had to be duplicated
CUSTOM_CONFIG_DIR="${CUSTOM_CONFIG_DIR:-}"
if [[ -z "${CUSTOM_CONFIG_DIR}" ]]; then
    IRONIC_CONF_DIR="/etc/ironic"
else
    IRONIC_CONF_DIR="${CUSTOM_CONFIG_DIR}/ironic"
fi

# Backward compatibility
if [[ "${IRONIC_DEPLOYMENT:-}" == "Conductor" ]]; then
    export IRONIC_EXPOSE_JSON_RPC=true
else
    export IRONIC_EXPOSE_JSON_RPC="${IRONIC_EXPOSE_JSON_RPC:-false}"
fi

IRONIC_HTPASSWD_FILE="${IRONIC_CONF_DIR}/htpasswd"
if [[ -f "/auth/ironic/htpasswd" ]]; then
    IRONIC_HTPASSWD=$(</auth/ironic/htpasswd)
fi
export IRONIC_HTPASSWD=${IRONIC_HTPASSWD:-${HTTP_BASIC_HTPASSWD:-}}

configure_client_basic_auth()
{
    local auth_config_file="/auth/$1/auth-config"
    local dest="${2:-${IRONIC_CONF_DIR}/ironic.conf}"
    if [[ -f "${auth_config_file}" ]]; then
        # Merge configurations in the "auth" directory into the default ironic configuration file
        crudini --merge "${dest}" < "${auth_config_file}"
    fi
}

configure_json_rpc_auth()
{
    if [[ "${IRONIC_EXPOSE_JSON_RPC}" == "true" ]]; then
        if [[ -z "${IRONIC_HTPASSWD}" ]]; then
            echo "FATAL: enabling JSON RPC requires authentication"
            exit 1
        fi
        printf "%s\n" "${IRONIC_HTPASSWD}" > "${IRONIC_HTPASSWD_FILE}-rpc"
    fi
}

configure_ironic_auth()
{
    local config="${IRONIC_CONF_DIR}/ironic.conf"
    # Configure HTTP basic auth for API server
    if [[ -n "${IRONIC_HTPASSWD}" ]]; then
        printf "%s\n" "${IRONIC_HTPASSWD}" > "${IRONIC_HTPASSWD_FILE}"
        if [[ "${IRONIC_REVERSE_PROXY_SETUP}" == "false" ]]; then
            crudini --set "${config}" DEFAULT auth_strategy http_basic
            crudini --set "${config}" DEFAULT http_basic_auth_user_file "${IRONIC_HTPASSWD_FILE}"
        fi
    fi
}

write_htpasswd_files()
{
    if [[ -n "${IRONIC_HTPASSWD:-}" ]]; then
        printf "%s\n" "${IRONIC_HTPASSWD}" > "${IRONIC_HTPASSWD_FILE}"
    fi
}
