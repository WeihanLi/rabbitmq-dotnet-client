#!/usr/bin/env bash

SCRIPT="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

MODE=${MODE:-keycloak}
IMAGE_TAG=${IMAGE_TAG:-3.11.15}
IMAGE=${IMAGE:-rabbitmq}

function generate-ca-server-client-kpi {
  NAME=$1

  if [ -d "$NAME" ]; then
    echo "SSL Certificates already present under $NAME. Skip SSL generation"
    return
  fi

  if [ ! -d "$SCRIPT/tls-gen" ]; then
    git clone https://github.com/michaelklishin/tls-gen $SCRIPT/tls-gen
  fi

  echo "Generating CA and Server PKI under $NAMER ..."
  mkdir -p $NAME
  cp -r $SCRIPT/tls-gen/* $NAME

  CUR_DIR=$(pwd)
  cd $NAME/basic
  make CN=localhost
  make PASSWORD=$PASSWORD
  make verify
  make info
  cd $CUR_DIR
}

function deploy {

  SIGNING_KEY_FILE=$SCRIPT/${MODE}/signing-key/signing-key.pem
  if [ -f "$SIGNING_KEY_FILE" ]; then
      EXTRA_MOUNTS="${EXTRA_MOUNTS} -v ${SIGNING_KEY_FILE}:/etc/rabbitmq/signing-key.pem"
  fi

  MOUNT_RABBITMQ_CONFIG="/etc/rabbitmq/rabbitmq.conf"
  CONFIG_DIR=$SCRIPT/$MODE

  docker network inspect rabbitmq_net >/dev/null 2>&1 || docker network create rabbitmq_net
  docker rm -f rabbitmq 2>/dev/null || echo "rabbitmq was not running"
  echo "running RabbitMQ ($IMAGE:$IMAGE_TAG) with Idp $MODE and configuration file $CONFIG_DIR/rabbitmq.conf"
  docker run -d --name rabbitmq --net rabbitmq_net \
      -p 15672:15672 -p 5672:5672 ${EXTRA_PORTS}\
      -v ${CONFIG_DIR}/rabbitmq.conf:${MOUNT_RABBITMQ_CONFIG}:ro \
      -v ${SCRIPT}/enabled_plugins:/etc/rabbitmq/enabled_plugins \
      -v ${CONFIG_DIR}:/conf ${EXTRA_MOUNTS} ${IMAGE}:${IMAGE_TAG}
}

deploy
