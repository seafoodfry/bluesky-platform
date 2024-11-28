IMG := instrumentatino-demo
CONATINER_OPTS := -e OTEL_SERVICE_NAME="demo" \
	-e OTEL_EXPORTER_OTLP_ENDPOINT="https://api.honeycomb.io" \
	-e OTEL_EXPORTER_OTLP_PROTOCOL="http/protobuf" \
	-e OTEL_EXPORTER_OTLP_HEADERS="x-honeycomb-team=$$(op read 'op://eng-vault/honeycomb-api-key/password')"

.PHONY: run
run:
	docker build -t $(IMG) .
	docker run -it $(CONATINER_OPTS) $(IMG)