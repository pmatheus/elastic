#!/bin/bash
set -e

# Vars
CERTS_DIR=/usr/share/kibana/config/certs # Adjusted path for Kibana container
ELASTIC_PASSWORD=${ELASTIC_PASSWORD:-}
KIBANA_HOST=kibana:5601
ES_HOST=es01:9200
POLICY_ID="fleet-server-policy"
TOKEN_NAME="fleet-docker-token-$(date +%s)"
TOKEN_FILE="${CERTS_DIR}/fleet_token.txt"

# Sanity check
if [ -z "$ELASTIC_PASSWORD" ]; then
  echo "[setup-fleet] ERROR: ELASTIC_PASSWORD is not set." >&2
  exit 1
fi
if [ ! -f "${CERTS_DIR}/ca/ca.crt" ]; then
  echo "[setup-fleet] ERROR: CA certificate not found at ${CERTS_DIR}/ca/ca.crt" >&2
  exit 1
fi

# 1. Wait for Kibana to be available
echo "[setup-fleet] ▶ Waiting for Kibana at https://${KIBANA_HOST}..."
until curl -s --cacert "${CERTS_DIR}/ca/ca.crt" "https://${KIBANA_HOST}/api/status" | grep -q '"level":"available"'; do
  echo "[setup-fleet] Kibana not available yet, retrying in 5 seconds..."
  sleep 5
done
echo "[setup-fleet] ✅ Kibana is available."

# 2. Create/Update Fleet Server Agent Policy via Kibana API (using PUT for idempotency)
echo "[setup-fleet] ▶ Creating/Updating Fleet Server policy '${POLICY_ID}' via Kibana API..."
POLICY_JSON='{
  "name": "Fleet-Server-Policy",
  "namespace": "default",
  "description": "Policy for Fleet Servers (managed by setup script)",
  "is_default_fleet_server": true,
  "package_policies": [
    {
      "name": "fleet_server-1",
      "package": { "name": "fleet_server" }
    },
    {
      "name": "elastic_agent-1",
      "package": { "name": "elastic_agent" }
    }
  ]
}'

# Loop until policy creation/update is successful
until curl -s --cacert "${CERTS_DIR}/ca/ca.crt" \
      -u "elastic:${ELASTIC_PASSWORD}" \
      -X PUT "https://${KIBANA_HOST}/api/fleet/agent_policies/${POLICY_ID}" \
      -H 'kbn-xsrf: true' \
      -H 'Content-Type: application/json' \
      -d "${POLICY_JSON}" \
      -o /dev/null --fail # Check for HTTP success (2xx)
do
  echo "[setup-fleet] Failed to create/update Fleet policy via Kibana (API might still be initializing), retrying in 5 seconds..."
  sleep 5
done
echo "[setup-fleet] ✅ Fleet Server policy created/updated successfully."


# 3. Generate Fleet Server Service Token via Elasticsearch API
echo "[setup-fleet] ▶ Generating Fleet Server service token via Elasticsearch API..."

# Loop until token generation is successful
until curl -s --cacert ${CERTS_DIR}/ca/ca.crt \
      -u "elastic:${ELASTIC_PASSWORD}" \
      -X POST "https://es01:9200/_security/service/elastic/fleet-server/credential/token/${TOKEN_NAME}" \
      -o /tmp/token_response.json --fail # Check for HTTP success
do
  echo "[setup-fleet] Failed to generate Fleet service token (ES API might be busy), retrying in 5 seconds..."
  sleep 5
done

# Extract the token
TOKEN_VALUE=$(sed -n 's/.*"value":"\([^"]*\)".*/\1/p' /tmp/token_response.json)

if [ -z "$TOKEN_VALUE" ]; then
  echo "[setup-fleet] ❌ ERROR: Could not extract token from response:" >&2
  cat /tmp/token_response.json >&2
  exit 1
fi

echo "[setup-fleet] ▶ Writing token to ${TOKEN_FILE}"
# Create directory if it doesn't exist (needed inside Kibana container)
mkdir -p "$(dirname "${TOKEN_FILE}")"
echo -n "${TOKEN_VALUE}" > "${TOKEN_FILE}"
# Ensure permissions allow fleet-server (user 1000) to read it later
# chown 1000:0 "${TOKEN_FILE}" # May not be needed if volumes handle permissions

rm /tmp/token_response.json # Clean up

echo "[setup-fleet] ✅ Fleet Server service token generated and saved."
echo "[setup-fleet] --- Fleet Setup Complete ---"
