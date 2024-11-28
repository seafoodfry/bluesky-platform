#!/bin/bash
#
# We used this to try out Grafana Tenpo
# We simply needed to add this to the container when running:
# -e OTEL_EXPORTER_OTLP_HEADERS="$$(bash setup-auth.sh)"
#
username=$(op read 'op://eng-vault/grafana-tempo-api-token/username')
api_key=$(op read 'op://eng-vault/grafana-tempo-api-token/credential')
echo "Authorization=Basic $(echo -n "${username}:${api_key}" | base64)"
