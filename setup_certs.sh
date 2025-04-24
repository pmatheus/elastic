#!/bin/bash

set -e

# Target directory for certificates inside the container
CERTS_DIR=/usr/share/elasticsearch/config/certs

# ────────────────────────────────────────────────────────────────
# 0. sanity-check passwords
# ────────────────────────────────────────────────────────────────
if [ -z "${ELASTIC_PASSWORD}" ] || [ -z "${KIBANA_PASSWORD}" ]; then
  echo "⛔ Set ELASTIC_PASSWORD and KIBANA_PASSWORD in the .env file"; exit 1;
fi

# ────────────────────────────────────────────────────────────────
# 1. CA generation   (only once)
#    Checks if the CA zip file already exists in the volume
# ────────────────────────────────────────────────────────────────
if [ ! -f ${CERTS_DIR}/ca.zip ]; then
  echo "▶ Creating certificate authority"
  # Use elasticsearch-certutil to create a CA
  bin/elasticsearch-certutil ca --silent --pem \
      -out ${CERTS_DIR}/ca.zip
  # Unzip the CA files into the certs directory
  unzip ${CERTS_DIR}/ca.zip -d ${CERTS_DIR}
else
  echo "CA already exists, skipping CA generation"
  echo $(ls -l ${CERTS_DIR})
fi

# ────────────────────────────────────────────────────────────────
# 2. node certificates   (es01, kibana, fleet-server)
#    Checks if the node certificates zip file already exists
# ────────────────────────────────────────────────────────────────
if [ ! -f ${CERTS_DIR}/certs.zip ]; then
  echo "▶ Creating node certificates"
  # Create an instances.yml file defining the nodes needing certs
  cat > ${CERTS_DIR}/instances.yml <<EOF
instances:
  - name: es01
    dns: [ "es01", "localhost" ]
    ip:  [ "127.0.0.1" ]
  - name: kibana
    dns: [ "kibana", "localhost" ]
    ip:  [ "127.0.0.1", "172.20.20.101" ]
  - name: fleet-server
    dns: [ "fleet-server", "localhost" ]
    ip:  [ "127.0.0.1", "172.20.20.101" ]
EOF
  # Use elasticsearch-certutil to create certs based on instances.yml and the CA
  bin/elasticsearch-certutil cert --silent --pem \
      --in  ${CERTS_DIR}/instances.yml \
      --out ${CERTS_DIR}/certs.zip \
      --ca-cert ${CERTS_DIR}/ca/ca.crt \
      --ca-key  ${CERTS_DIR}/ca/ca.key
  # Unzip the node certificates into the certs directory
  unzip ${CERTS_DIR}/certs.zip -d ${CERTS_DIR}
fi

# ────────────────────────────────────────────────────────────────
# 3. fix permissions so non-root containers can read the files
#    Sets ownership to user 1000 (common for elastic stack) and group 0 (root)
#    Sets permissions: owner=rw, group=r, other=--- for files
#                      owner=rwx, group=rx, other=--- for directories
# ────────────────────────────────────────────────────────────────
echo "▶ Setting certificate permissions"
chown -R 1000:0 ${CERTS_DIR}
find ${CERTS_DIR} -type d -exec chmod 750 {} \;
find ${CERTS_DIR} -type f -exec chmod 640 {} \;


echo $(du -sh ${CERTS_DIR})

echo "✅ Certificates created and permissions set"
