# PEP: Tweet De-duplication


# Summary




---
# Motivation

We want to come up with a way to prevent the duplication of posts scraped.
We are going to try leveraging AWS ElasticCache because of its scalability and decent cost.


## Goals

- prevent us from storing duplicated posts

## Non-Goals



---
# Proposal


## Risks ad Mitigations



---
# Design Details


* Amazon ElastiCache is a fully managed, Valkey, Memcached- and Redis OSS.
* ElastiCache speeds up database and application performance, scaling to millions of operations per second with microsecond response time.
    * unlocks cost savings for read-heavy.
    * Store frequently used data in memory for microsecond response times and high throughput to support hundreds of millions of operations per second.
* ElastiCache Global Datastore offers localized reads through fully-managed cross-Region replication.
* Serverless option that allows customers to create a cache in under a minute and instantly scale capacity based on application traffic patterns.
    * Operate a cache for even the most demanding workloads without spending time in capacity planning or requiring caching expertise.
    * Constantly monitors your application’s memory, CPU, and network resource utilization and scales instantly to accommodate changes to the access patterns of workloads it serves.

You can also set maximum limits for your compute and memory usage to ensure your cache doesn’t grow beyond a certain size. When your cache reaches the memory limit, keys with a time to live (TTL) are evicted according to the least recently used (LRU) logic. When your compute limit is reached, ElastiCache will throttle requests, which will lead to elevated request latencies.


```hcl
# See
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/elasticache_serverless_cache
resource "aws_elasticache_serverless_cache" "valkey" {
  name        = "valkey"
  description = "post dedup pipeline"
  engine      = "valkey"
  cache_usage_limits {
    data_storage {
      maximum = 10
      unit    = "GB"
    }
    ecpu_per_second {
      maximum = 5000
    }
  }
  major_engine_version     = "7"
  daily_snapshot_time      = "09:00"
  snapshot_retention_limit = 3
  kms_key_id               = aws_kms_key.valkey.arn
  security_group_ids       = [aws_security_group.valkey.id]
  subnet_ids               = module.vpc.public_subnets[*]
}
```

https://valkey.io/topics/quickstart/

## Valeky Tutorial

```
$ docker inspect -f '{{range.NetworkSettings.Networks}}{{.IPAddress}}{{end}}' valkey-server
172.18.0.2
```

```
root@262b0071da20:/data# valkey-cli -h 172.18.0.2 INCR counter
(integer) 1
root@262b0071da20:/data# valkey-cli -h 172.18.0.2 INCR counter
(integer) 2
root@262b0071da20:/data# valkey-cli -h 172.18.0.2 INCR counter
(integer) 3
```

## Costs

> You can further optimize costs on ElastiCache Serverless for Valkey with 33% lower pricing and 90% lower minimum data storage of 100 MB compared to other supported engines.

> Reads and writes require 1 ECPU for each kilobyte (KB) of data transferred.
> For example, a GET command that transfers 3.2 KB of data will consume 3.2 ECPUs.

We'll chose valkey because the price for data store is almost half the price of redis.
The price of processing units is $0.001 (ish) more.

See
[aws.amazon.com/elasticache/pricing/](https://aws.amazon.com/elasticache/pricing/)
for more details.


## Test Plans


## Graduation Criteria



---
# Production Readiness



---
# Implementation History

- [./app](./app/)

---
# Drawbacks


---
# Alternatives



---
# Insfrasturcture Needed
