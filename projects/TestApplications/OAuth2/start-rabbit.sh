#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail

script_dir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
readonly script_dir

readonly mode="${mode:-keycloak}"
readonly image_tag="${IMAGE_TAG:-3-management}"
readonly image="${IMAGE:-rabbitmq}"

source "$script_dir/common.sh"

readonly docker_name="$docker_name_prefix-rabbitmq"

function generate-ca-server-client-kpi
{
    local -r name="$1"

    if [[ -d $name ]]
    then
        echo "[INFO] SSL Certificates already present under $name. Skip SSL generation"
        return
    fi

    if [[ ! -d $script_dir/tls-gen ]]
    then
        git submodule update --init
    fi

    echo "[INFO] Generating CA and Server PKI under $name ..."
    mkdir -p "$name"
    cp -r "$script_dir"/tls-gen/* "$name"

    (
        cd "$name/basic"
        make CN=localhost
        make "PASSWORD=$OAUTH2_CERT_PASSWORD"
        make verify
        make info
    )
}

function deploy
{
    local -r signing_key_file="$script_dir/$mode/signing-key/signing-key.pem"
    if [[ -f $signing_key_file ]]
    then
        OAUTH2_RABBITMQ_EXTRA_MOUNTS="${OAUTH2_RABBITMQ_EXTRA_MOUNTS:-} -v $signing_key_file:/etc/rabbitmq/signing-key.pem"
    fi

    local -r mount_rabbitmq_config="/etc/rabbitmq/rabbitmq.conf"
    local -r config_dir="$script_dir/$mode"

    docker network inspect rabbitmq_net >/dev/null 2>&1 || docker network create rabbitmq_net
    docker rm -f "$docker_name" 2>/dev/null || echo "[INFO] $docker_name was not running"

    echo "[INFO] running RabbitMQ ($image:$image_tag) with Idp $mode and configuration file $config_dir/rabbitmq.conf"

    # Note:
    # Variables left un-quoted so that words are actually split as args
    # shellcheck disable=SC2086
    docker run -d --name "$docker_name" --net rabbitmq_net \
        -p '15672:15672' -p '5672:5672' ${OAUTH2_RABBITMQ_EXTRA_PORTS:-} \
        -v "$config_dir/rabbitmq.conf:$mount_rabbitmq_config:ro" \
        -v "$script_dir/enabled_plugins:/etc/rabbitmq/enabled_plugins" \
        -v "$config_dir:/conf" ${OAUTH2_RABBITMQ_EXTRA_MOUNTS:-} "$image:$image_tag"
}

deploy
