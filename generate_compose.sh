#!/bin/bash

# Usage: ./generate_compose.sh <env_file> <template_file.tpl.yml>

if [[ $# -ne 2 ]]; then
    echo "Usage: $0 <env_file> <template_file.tpl.yml>"
    exit 1
fi

ENV_FILE="$1"
TEMPLATE_FILE="$2"

if [[ ! -f "$ENV_FILE" ]]; then
    echo "❌ File $ENV_FILE not found."
    exit 1
fi

if [[ ! -f "$TEMPLATE_FILE" ]]; then
    echo "❌ File $TEMPLATE_FILE not found."
    exit 1
fi

# Load variables from the file
set -o allexport
source "$ENV_FILE"
set +o allexport

# Execute this part only if the input file is main-stack.tpl.yml
if [[ "$(basename "$TEMPLATE_FILE")" == "main-stack.tpl.yml" ]]; then
    # ✅ Validate CERT_RESOLVER
    if [[ -z "$CERT_RESOLVER" ]]; then
        echo "❌ CERT_RESOLVER variable not set in $ENV_FILE"
        exit 1
    fi

    PROVIDER="$CERT_RESOLVER"

    # Generate environment block for Traefik
    TRAEFIK_ENV_BLOCK=""
    case "$PROVIDER" in
        ovh)
            TRAEFIK_ENV_BLOCK=$(cat <<EOF
                - OVH_ENDPOINT=$OVH_ENDPOINT
                - OVH_APPLICATION_KEY=$OVH_APPLICATION_KEY
                - OVH_APPLICATION_SECRET=$OVH_APPLICATION_SECRET
                - OVH_CONSUMER_KEY=$OVH_CONSUMER_KEY
EOF
    ) ;;
        cloudflare)
            TRAEFIK_ENV_BLOCK=$(cat <<EOF
                - CF_API_EMAIL=$CF_API_EMAIL
                - CF_API_KEY=$CF_API_KEY
EOF
    ) ;;
        duckdns)
            TRAEFIK_ENV_BLOCK=$(cat <<EOF
                - DUCKDNS_TOKEN=$DUCKDNS_TOKEN
                - DUCKDNS_PROPAGATION_TIMEOUT=120
EOF
    ) ;;
        *)
            echo "❌ Provider $PROVIDER is not supported."
            exit 1
            ;;
    esac

    export TRAEFIK_ENV_BLOCK

    # Check if ./registry/auth/htpasswd exists and export its content
    HTPASSWD_FILE="./registry/auth/htpasswd"
    if [[ -f "$HTPASSWD_FILE" ]]; then
        TRAEFIK_AUTH=$(cat "$HTPASSWD_FILE")
        export TRAEFIK_AUTH
    else
        echo "❌ $HTPASSWD_FILE not found."
        exit 1
    fi

fi

# Output file: remove .tpl from template filename
OUTPUT_FILE="${TEMPLATE_FILE/.tpl/}"

envsubst < "$TEMPLATE_FILE" > "$OUTPUT_FILE"
echo "✅ $OUTPUT_FILE file generated for template: $TEMPLATE_FILE using environment variables from $ENV_FILE"