# Demo App

To run the app you wil need Grafana CLoud credentials.
Specifically an API key to send traces via OTel.

We got said API key and saved it in 1Password.
Then we used the OP CLI to securely pass the secret to our demo app.
You'll see traces (hah!) of this in the [Makefile](./Makefile).

---
# Setup

```
poetry add opentelemetry-instrumentation \
    opentelemetry-distro \
    opentelemetry-exporter-otlp
```

```
poetry run opentelemetry-bootstrap
```

We added the following as well:
```
opentelemetry-instrumentation-asyncio==0.49b2
opentelemetry-instrumentation-dbapi==0.49b2
opentelemetry-instrumentation-logging==0.49b2
opentelemetry-instrumentation-sqlite3==0.49b2
opentelemetry-instrumentation-threading==0.49b2
opentelemetry-instrumentation-urllib==0.49b2
opentelemetry-instrumentation-wsgi==0.49b2
opentelemetry-instrumentation-grpc==0.49b2
opentelemetry-instrumentation-requests==0.49b2
opentelemetry-instrumentation-urllib3==0.49b2
```

Also added
```
poetry add opentelemetry-api
poetry add opentelemetry-processor-baggage
```

---
# References
1. [OTel asyncio](https://opentelemetry-python-contrib.readthedocs.io/en/latest/instrumentation/asyncio/asyncio.html)
1. [Honeycomb Sampling](https://docs.honeycomb.io/send-data/python/opentelemetry-sdk/#sampling)