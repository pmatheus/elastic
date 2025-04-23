#!/usr/bin/env bash
set -euo pipefail
cd /usr/share/elasticsearch

###############################################################################
# add unzip if the image no longer has it (8.18 dropped it on some builds)
###############################################################################
if ! command -v unzip &>/dev/null ; then
  echo "→ Installing unzip inside the container"
  apt-get update -qq
  DEBIAN_FRONTEND=noninteractive apt-get install -y -qq unzip
fi
###############################################################################

mkdir -p config/certs

if [[ ! -f config/certs/ca.zip ]]; then
  echo "→ Creating CA"
  bin/elasticsearch-certutil ca --silent --pem -out config/certs/ca.zip
  unzip -o config/certs/ca.zip -d config/certs
fi

if [[ ! -f config/certs/certs.zip ]]; then
  echo "→ Creating node certs"
  bin/elasticsearch-certutil cert --silent --pem \
    --in  config/instances.yml \
    --out config/certs/certs.zip \
    --ca-cert config/certs/ca/ca.crt \
    --ca-key  config/certs/ca/ca.key
  unzip -o config/certs/certs.zip -d config/certs
fi

chown -R root:root config/certs
find  config/certs -type d -exec chmod 750 {} \;
find  config/certs -type f -exec chmod 640 {} \;
