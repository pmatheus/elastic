#!/bin/bash

set -e

# Target directory for certificates inside the container (needed for CA cert)
CERTS_DIR=/usr/share/elasticsearch/config/certs

# ────────────────────────────────────────────────────────────────
# Wait for Elasticsearch (es01) then set kibana_system password
# ────────────────────────────────────────────────────────────────
echo "[setup-passwords] ▶ Waiting for es01 service to be healthy..."
# This script relies on docker-compose's depends_on condition for es01 health,
# but we add a small initial sleep just in case.
sleep 5

echo "[setup-passwords] ▶ Checking es01 availability..."
# Loop until Elasticsearch is reachable and reports missing authentication (means it's up)
# until curl -s -k https://es01:9200 \
#       --fail -o /dev/null # --fail causes curl to exit non-zero on HTTP errors
# do
#   echo "[setup-passwords] es01 not responding yet, retrying in 5 seconds..."
#   sleep 5
# done
#print the output of curl for debugging
until curl -s -u "elastic:${ELASTIC_PASSWORD}" -k https://es01:9200/_cluster/health \
      --fail -o /dev/null # --fail causes curl to exit non-zero on HTTP errors
do
  echo "[setup-passwords] curl output: $(curl -u "elastic:${ELASTIC_PASSWORD}" -k https://es01:9200/_cluster/health)"
  echo "[setup-passwords] es01 not responding yet, retrying in 5 seconds..."
  sleep 5
done
echo "[setup-passwords] ▶ Setting kibana_system password"
# Loop until the password setting request is successful (returns status 200 OK)
until curl -s --cacert ${CERTS_DIR}/ca/ca.crt \
      -u "elastic:${ELASTIC_PASSWORD}" \
      -X POST "https://es01:9200/_security/user/kibana_system/_password" \
      -H "Content-Type: application/json" \
      -d "{\"password\":\"${KIBANA_PASSWORD}\"}" \
      --fail -o /dev/null # Check for HTTP success
do
  echo "[setup-passwords] Failed to set kibana_system password (es01 might still be initializing), retrying in 5 seconds..."
  sleep 5
done

echo "[setup-passwords] ✅ kibana_system password set successfully"
