import time
import logging
import random

from opentelemetry import trace

from opentelemetry import trace, baggage
from opentelemetry.context import attach, detach


# Configure debug logging.
logging.basicConfig(level=logging.DEBUG)

"""
The following is useful if we were not using the OTel wrapper to run the code:

import os
import base64
from opentelemetry import trace
from opentelemetry.exporter.otlp.proto.http.trace_exporter import OTLPSpanExporter
from opentelemetry.sdk.trace import TracerProvider
from opentelemetry.sdk.trace.export import BatchSpanProcessor

username = os.environ["TEMPO_USERNAME"]
api_key = os.environ["TEMPO_API_KEY"]

# Create basic auth header.
# base64.b64encode() creates the base64 representation, but returns it as bytes.
# That's why we end decoding it.
auth = base64.b64encode(f"{username}:{api_key}".encode()).decode()
headers = {
    "Authorization": f"Basic {auth}"
}

# Initialize the OTLP exporter.
otlp_exporter = OTLPSpanExporter(
    endpoint=os.environ["OTEL_EXPORTER_OTLP_ENDPOINT"],
    headers=headers
)

# Set up the trace provider.
provider = TracerProvider()
processor = BatchSpanProcessor(otlp_exporter)
provider.add_span_processor(processor)
trace.set_tracer_provider(provider)
"""

tracer = trace.get_tracer("demo")


@tracer.start_as_current_span("main")
def main():
    token = attach(
    baggage.set_baggage("user.id", "x-123"))

    with tracer.start_as_current_span("main") as span:
        span.set_attribute("message", "hello world!")
        print('hello')

        with tracer.start_as_current_span("nested_operation") as span2:
            span2.set_attribute("test.attribute", "value2")
            print("Nested operation")
            r = random.randint(0, 10)
            span.set_attribute("time", r)
            time.sleep(r)

    detach(token)

if __name__ == '__main__':
    for _ in range(100):
        main()
        time.sleep(1)