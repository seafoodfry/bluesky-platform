IMG := instrumentatino-demo
CONATINER_OPTS := -e OTEL_SERVICE_NAME="demo" \
	-e OTEL_EXPORTER_OTLP_ENDPOINT="https://api.honeycomb.io" \
	-e OTEL_EXPORTER_OTLP_PROTOCOL="http/protobuf" \
	-e OTEL_EXPORTER_OTLP_HEADERS="x-honeycomb-team=$$(op read 'op://eng-vault/honeycomb-api-key/password')"

NET := valkey

.PHONY: run
run:
	docker build -t $(IMG) .
	docker run -it $(CONATINER_OPTS) $(IMG)

.PHONY: valkey
valkey:
	docker network inspect $(NET) || docker network create $(NET)
	docker network list
	docker build -t valkey-server -f Dockerfile.valkey .
	mkdir -p valkey-data
	docker run -d --rm --network $(NET) -v $(PWD)/valkey-data:/data --name valkey-server valkey-server
	docker run -it --rm --network $(NET) --name valkey-client valkey-server bash

,PHONY: cleanup-valkey
valkey-cleanup:
	docker stop valkey-server
	docker network rm $(NET)