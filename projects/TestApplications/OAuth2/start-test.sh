#!/usr/bin/env bash

set -x

SCRIPT="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

MODE=${MODE:-keycloak}
CLIENT_ID=producer

if [ $MODE == "keycloak" ]
then
  CLIENT_SECRET=kbOFBXI9tANgKUq8vXHLhT6YhbivgXxn
  TOKEN_ENDPOINT="http://localhost:8080/realms/test/protocol/openid-connect/token"
  SCOPE="rabbitmq:configure:*/* rabbitmq:read:*/* rabbitmq:write:*/*"
else
  CLIENT_SECRET=producer_secret
  TOKEN_ENDPOINT="http://localhost:8080/oauth/token"
  SCOPE=""
fi

dotnet run --Name $MODE \
  --ClientId $CLIENT_ID \
  --ClientSecret $CLIENT_SECRET \
  --Scope "$SCOPE" \
  --TokenEndpoint $TOKEN_ENDPOINT \
  --TokenExpiresInSeconds 60
