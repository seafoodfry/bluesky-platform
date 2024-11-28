# PEP: Instrumentation


# Summary

We tried grafana cloud.
It wasn't good.
It suffers from a similar issue as datadog: getting started once the data is in the vendor is to irksome and once you do
figure out how to use the data, you have to create separate visualizations to understand your app.
This limits one's capacities to explore the data as compared to honeycomb where using the data and the visualizations are
already figured out and ready to be used so that user's just need to mix and match to understand what is going on.


---
# Motivation

Distributed tracing is the best thing one can do for themselves.

The best obserbability platform we have come across is
[honeycomb](https://www.honeycomb.io/) - we've tried datadog, new relic, jaeger, AWS xray, and another that shall not be named.
It is our opinion that none of the come even close to being as useful as Honeycomb.

However, we needed an excuse to try out hosted grafana products, as recommended and encouraged in
[grafana docs: getting-started oss-tempo](https://grafana.com/docs/tempo/latest/getting-started/?pg=oss-tempo&plcmt=resources).

We have previously always ran Grafana products manually.
For production instances we've used things such as
[https://github.com/prometheus-operator/prometheus-operator].

For proofs-of-concept we've written up examples such as
[github.com/contributing-to-kubernetes/go-examples/lesson-002-prometheus-metrics](https://github.com/contributing-to-kubernetes/go-examples/tree/master/lesson-002-prometheus-metrics).

This proposal is to document how we will be instrumenting our scrapers, hooking them up to hosted Grafana tempo, and evaluating the platform (comparing it to honeycomb).


## Goals

- have good tools for obserbability
- do eough to get a feel for grafana with tempo

## Non-Goals

- go into rabbit holes dealing with logs or metrics
- document how to use tempo with grafana


---
# Proposal

Use honeycomb to instrument our apps.

## Risks ad Mitigations

This sends data to a vendor.
So another preprocessor one would use in real life.

---
# Design Details

1. Sign up for a Grafana Cloud account.

2. Instrument the app. See [./app/README](./app/README.md).

3. Enable metrics generation [grafana/metrics-generator/](https://grafana.com/docs/grafana-cloud/send-data/traces/metrics-generator/).

## Test Plans

We wrote a test-app as part of this work in [./app](./app/).
But this feature is meant to help us test better in production.

## Graduation Criteria

- [ ] document how to use otel with asyncio
- [ ] instrument scrapers
- [ ] document how to use different sampling methods

---
# Production Readiness

- [ ] at least one scraper is instrumented
- [ ] come up with a good pattern to jot down findings

---
# Implementation History

- [./app](./app/) has the basic of how to instrument a container to send traces

---
# Drawbacks

Instrumentation adds more wrapper-like code that we need to maintain.

---
# Alternatives

No good alternatives.
This is the best observability vendor we've tried.

---
# Insfrasturcture Needed

An API key.
