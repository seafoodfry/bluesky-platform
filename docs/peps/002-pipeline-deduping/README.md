# PEP: Tweet De-duplication


# Summary

WIP


---
# Motivation

We want to come up with a way to prevent the duplication of posts scraped.
We want to document some common patterns ('cas they are common) for how to do things like this.

## Goals

- Document the basics for doing content deduplication like tasks with the following:
  - Elasticache
  - DynamoDB
  - RDS
  - Dask

## Non-Goals

- Figure out what is the best Rick and Morty episode


---
# Proposal


## Risks ad Mitigations



---
# Design Details

## Valkey

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


### Valeky Tutorial

https://valkey.io/topics/quickstart/

and

https://github.com/valkey-io/valkey-py


## Valkey Costs

**Context:** we are considering this option because elasticache can be restored (data persistance)
and because we don't really care about our datasets being available for a long long time.

Valkey is the best option because the price for data store is almost half the price of redis.

> You can further optimize costs on ElastiCache Serverless for Valkey with 33% lower pricing and 90% lower minimum data storage of 100 MB compared to other supported engines.

Elasticache in serverless mode is the best option, we think.
In this mode we need to think in terms of "Elasticache Processing Units", which are defined as follows

> Reads and writes require 1 ECPU for each kilobyte (KB) of data transferred.
> For example, a GET command that transfers 3.2 KB of data will consume 3.2 ECPUs.


In serverless mode, the charges are

1. $0.084 / GB-hour of serverless elasticache
1. $0.0023 / million ECPUs
1. $0.045	/ NAT gateway hour
1. $0.045 / GB of data processed

So to put everything into a comparable footing:

1. $0.084 / GB-hour of serverless elasticache
1. $2.3 / billion ECPUs which is about $2.3 / GB of data processed by elasticache
1. $0.045	/ NAT gateway hour
1. $0.045 / GB of data processed

So let's guesstimate this further and say:

1. $2.43 / GB of data

We dropped the NAT gateway charge per hour because we will have the NAT gateway anyway.


See
[aws.amazon.com/elasticache/pricing/](https://aws.amazon.com/elasticache/pricing/)
and
[aws.amazon.com/vpc/pricing/](https://aws.amazon.com/vpc/pricing/)
for more details.


---

## RDS

```sql
-- Create the tweets table with a composite index
CREATE TABLE tweets (
    id SERIAL PRIMARY KEY,
    handle VARCHAR(50) NOT NULL,
    message TEXT NOT NULL,
    name VARCHAR(100),
    hours_ago FLOAT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    -- Composite index on handle + message
    CONSTRAINT unique_handle_message UNIQUE (handle, message)
);

-- This creates a B-tree index that stores handle+message pairs in sorted order
CREATE INDEX idx_handle_message ON tweets(handle, message);

-- Example insertions that work
INSERT INTO tweets (handle, message, name, hours_ago)
VALUES ('@johnd', 'Hello world!', 'John Doe', 2.5);

INSERT INTO tweets (handle, message, name, hours_ago)
VALUES ('@jane', 'Hello world!', 'Jane Smith', 1.0);  -- Different handle, same message OK

-- This would fail due to unique constraint
INSERT INTO tweets (handle, message, name, hours_ago)
VALUES ('@johnd', 'Hello world!', 'John Doe', 3.0);  -- Duplicate handle+message

-- Efficient query using the composite index
EXPLAIN ANALYZE
SELECT * FROM tweets 
WHERE handle = '@johnd' AND message = 'Hello world!';

-- Uses index but less efficient (only uses handle part of index)
EXPLAIN ANALYZE
SELECT * FROM tweets 
WHERE handle = '@johnd';

-- Doesn't use the index at all
EXPLAIN ANALYZE
SELECT * FROM tweets 
WHERE message = 'Hello world!';

-- If you need to batch insert while ignoring duplicates:
INSERT INTO tweets (handle, message, name, hours_ago)
VALUES 
    ('@johnd', 'Hello world!', 'John Doe', 2.5),
    ('@jane', 'Hello world!', 'Jane Smith', 1.0)
ON CONFLICT (handle, message) DO NOTHING;

-- If you need to update on duplicate:
INSERT INTO tweets (handle, message, name, hours_ago)
VALUES ('@johnd', 'Hello world!', 'John Doe', 2.5)
ON CONFLICT (handle, message) 
DO UPDATE SET hours_ago = EXCLUDED.hours_ago;
```

In python

```python
from datetime import datetime
from typing import List, Optional
from sqlalchemy import create_engine, UniqueConstraint, Index
from sqlalchemy.orm import declarative_base, Session, sessionmaker
from sqlalchemy import Column, Integer, String, Text, Float, DateTime
from sqlalchemy.dialects.postgresql import insert

Base = declarative_base()

class Tweet(Base):
    __tablename__ = 'tweets'
    
    id = Column(Integer, primary_key=True)
    handle = Column(String(50), nullable=False)
    message = Column(Text, nullable=False)
    name = Column(String(100))
    hours_ago = Column(Float)
    created_at = Column(DateTime, default=datetime.utcnow)
    
    # Composite unique constraint that creates an index automatically
    __table_args__ = (
        UniqueConstraint('handle', 'message', name='unique_handle_message'),
    )

class TweetIngester:
    def __init__(self, db_url: str):
        self.engine = create_engine(db_url)
        Base.metadata.create_all(self.engine)
        self.Session = sessionmaker(bind=self.engine)
    
    def ingest_tweets(self, tweets: List[dict], batch_size: int = 1000) -> tuple[int, int]:
        """
        Ingest tweets with automatic deduplication.
        Returns (successful_inserts, duplicates_skipped)
        """
        session = self.Session()
        try:
            # Prepare the upsert statement
            stmt = insert(Tweet).values(tweets)
            
            # On conflict, do nothing (skip duplicates)
            stmt = stmt.on_conflict_do_nothing(
                constraint='unique_handle_message'
            )
            
            result = session.execute(stmt)
            session.commit()
            
            # Return number of rows inserted and duplicates skipped
            return result.rowcount, len(tweets) - result.rowcount
            
        except Exception as e:
            session.rollback()
            raise e
        finally:
            session.close()
    
    def get_tweet(self, handle: str, message: str) -> Optional[Tweet]:
        """Efficiently retrieve a tweet using the composite index"""
        session = self.Session()
        try:
            return session.query(Tweet).filter_by(
                handle=handle,
                message=message
            ).first()
        finally:
            session.close()

# Example usage
if __name__ == "__main__":
    # Initialize with your RDS connection string
    ingester = TweetIngester('postgresql://{user}:{pass}@{hostname}:5432/{dbname}')
    
    # Sample data
    tweets_to_ingest = [
        {
            "handle": "@johnd",
            "message": "Hello world!",
            "name": "John Doe",
            "hours_ago": 2.5
        },
        {
            "handle": "@jane",
            "message": "Hello world!", # Different handle, will be inserted
            "name": "Jane Smith",
            "hours_ago": 1.0
        },
        {
            "handle": "@johnd",
            "message": "Hello world!", # Duplicate, will be skipped
            "name": "John Doe",
            "hours_ago": 3.0
        }
    ]
    
    # Ingest with automatic deduplication
    inserted, skipped = ingester.ingest_tweets(tweets_to_ingest)
    print(f"Inserted {inserted} tweets, skipped {skipped} duplicates")
    
    # Check for a specific tweet
    tweet = ingester.get_tweet("@johnd", "Hello world!")
    if tweet:
        print(f"Found tweet from {tweet.name} posted {tweet.hours_ago} hours ago")
```


```python
import time
import random
import string
import pandas as pd
import numpy as np
from typing import List, Tuple
from sqlalchemy import create_engine, text
from concurrent.futures import ThreadPoolExecutor
import matplotlib.pyplot as plt
from dataclasses import dataclass

@dataclass
class BatchTestResult:
    batch_size: int
    total_time: float
    throughput: float
    memory_mb: float

def generate_test_tweet() -> dict:
    """Generate a random tweet-like message"""
    return {
        "handle": f"@user_{random.randint(1, 1000)}",
        "message": ''.join(random.choices(string.ascii_letters + ' ', k=100)),
        "name": f"User {random.randint(1, 1000)}",
        "hours_ago": random.uniform(0, 24)
    }

class BatchSizeOptimizer:
    def __init__(self, db_url: str):
        self.engine = create_engine(db_url)
        
    def _clear_test_data(self):
        """Clear test data between runs"""
        with self.engine.connect() as conn:
            conn.execute(text("TRUNCATE TABLE tweets"))
            conn.commit()
    
    def _measure_memory(self) -> float:
        """Get approximate memory usage of table in MB"""
        query = """
        SELECT pg_total_relation_size('tweets') / 1024.0 / 1024.0 
        AS size_mb;
        """
        with self.engine.connect() as conn:
            result = conn.execute(text(query)).scalar()
            return float(result)

    def test_batch_size(self, batch_size: int, total_records: int) -> BatchTestResult:
        """Test performance with a specific batch size"""
        self._clear_test_data()
        
        # Generate all test data upfront
        tweets = [generate_test_tweet() for _ in range(total_records)]
        
        # Split into batches
        batches = [tweets[i:i + batch_size] 
                  for i in range(0, len(tweets), batch_size)]
        
        start_time = time.time()
        
        # Process batches
        for batch in batches:
            stmt = text("""
                INSERT INTO tweets (handle, message, name, hours_ago)
                VALUES (:handle, :message, :name, :hours_ago)
                ON CONFLICT (handle, message) DO NOTHING
            """)
            with self.engine.begin() as conn:
                conn.execute(stmt, batch)
        
        total_time = time.time() - start_time
        memory_mb = self._measure_memory()
        throughput = total_records / total_time
        
        return BatchTestResult(
            batch_size=batch_size,
            total_time=total_time,
            throughput=throughput,
            memory_mb=memory_mb
        )

    def find_optimal_batch_size(self, 
                              min_batch: int = 100, 
                              max_batch: int = 10000,
                              step: int = 100,
                              total_records: int = 100000) -> List[BatchTestResult]:
        """Test different batch sizes and return results"""
        batch_sizes = range(min_batch, max_batch + step, step)
        results = []
        
        for batch_size in batch_sizes:
            print(f"Testing batch size: {batch_size}")
            result = self.test_batch_size(batch_size, total_records)
            results.append(result)
            
        return results

def plot_results(results: List[BatchTestResult]):
    """Create visualization of batch size test results"""
    df = pd.DataFrame([vars(r) for r in results])
    
    fig, (ax1, ax2) = plt.subplots(1, 2, figsize=(15, 6))
    
    # Throughput plot
    ax1.plot(df['batch_size'], df['throughput'], marker='o')
    ax1.set_title('Throughput vs Batch Size')
    ax1.set_xlabel('Batch Size')
    ax1.set_ylabel('Records per Second')
    
    # Memory plot
    ax2.plot(df['batch_size'], df['memory_mb'], marker='o', color='orange')
    ax2.set_title('Memory Usage vs Batch Size')
    ax2.set_xlabel('Batch Size')
    ax2.set_ylabel('Memory (MB)')
    
    plt.tight_layout()
    return fig

# Example usage
if __name__ == "__main__":
    optimizer = BatchSizeOptimizer('postgresql://{user}:{pass}@{hostname}:5432/{dbname}')
    
    # Test range of batch sizes
    results = optimizer.find_optimal_batch_size(
        min_batch=100,
        max_batch=5000,
        step=100,
        total_records=100000
    )
    
    # Find optimal batch size based on throughput
    optimal = max(results, key=lambda x: x.throughput)
    print(f"\nOptimal batch size: {optimal.batch_size}")
    print(f"Throughput: {optimal.throughput:.2f} records/second")
    print(f"Memory usage: {optimal.memory_mb:.2f} MB")
    
    # Create visualization
    plot_results(results)
```

### Costs


---
## DynamoDB


### DynamoDB Tutorial

```python
# RDS (PostgreSQL) Approach
from sqlalchemy import create_engine, text

class RDSDedupSystem:
    def __init__(self, db_url: str):
        self.engine = create_engine(db_url)
    
    def ingest_tweets(self, tweets: List[dict]) -> tuple[int, int]:
        stmt = text("""
            INSERT INTO tweets (handle, message, name, hours_ago)
            VALUES (:handle, :message, :name, :hours_ago)
            ON CONFLICT (handle, message) DO NOTHING
            RETURNING id
        """)
        with self.engine.begin() as conn:
            result = conn.execute(stmt, tweets)
            return result.rowcount, len(tweets) - result.rowcount

# ElastiCache (Redis) Approach
import redis

class RedisDedupSystem:
    def __init__(self, redis_url: str):
        self.redis = redis.from_url(redis_url)
    
    def get_key(self, tweet: dict) -> str:
        return f"tweet:{tweet['handle']}:{hash(tweet['message'])}"
    
    def ingest_tweets(self, tweets: List[dict]) -> tuple[int, int]:
        pipeline = self.redis.pipeline()
        keys = []
        
        # Prepare all SET NX operations
        for tweet in tweets:
            key = self.get_key(tweet)
            keys.append(key)
            # SET NX with 48 hour expiry (adjust based on your needs)
            pipeline.set(key, '1', nx=True, ex=172800)
        
        # Execute pipeline
        results = pipeline.execute()
        successful = sum(1 for r in results if r)
        return successful, len(tweets) - successful

# DynamoDB Approach
import boto3
from botocore.exceptions import ClientError

class DynamoDedupSystem:
    def __init__(self, table_name: str):
        self.dynamo = boto3.resource('dynamodb')
        self.table = self.dynamo.Table(table_name)
    
    def ingest_tweets(self, tweets: List[dict]) -> tuple[int, int]:
        successful = 0
        
        # DynamoDB batch writer handles retries and batching
        with self.table.batch_writer() as batch:
            for tweet in tweets:
                try:
                    batch.put_item(
                        Item={
                            'HandleMessage': f"{tweet['handle']}#{tweet['message']}",  # partition key
                            'CreatedAt': int(time.time()),  # sort key
                            'Name': tweet['name'],
                            'HoursAgo': tweet['hours_ago']
                        },
                        ConditionExpression='attribute_not_exists(HandleMessage)'
                    )
                    successful += 1
                except ClientError as e:
                    if e.response['Error']['Code'] != 'ConditionalCheckFailedException':
                        raise
        
        return successful, len(tweets) - successful

"""
DynamoDB Table Definition:

{
    "TableName": "Tweets",
    "KeySchema": [
        {
            "AttributeName": "HandleMessage",
            "KeyType": "HASH"
        },
        {
            "AttributeName": "CreatedAt",
            "KeyType": "RANGE"
        }
    ],
    "AttributeDefinitions": [
        {
            "AttributeName": "HandleMessage",
            "AttributeType": "S"
        },
        {
            "AttributeName": "CreatedAt",
            "AttributeType": "N"
        }
    ],
    "ProvisionedThroughput": {
        "ReadCapacityUnits": 5,
        "WriteCapacityUnits": 5
    }
}
"""

# Example usage showing how data flows differently in each system
def compare_approaches():
    # Initialize systems
    rds = RDSDedupSystem('postgresql://{user}:{pass}@{hostname}:5432/{dbname}')
    redis = RedisDedupSystem('redis://{hostname}:6379/0')
    dynamo = DynamoDedupSystem('Tweets')
    
    test_tweets = [
        {
            "handle": "@user1",
            "message": "Hello world!",
            "name": "User One",
            "hours_ago": 1.0
        },
        {
            "handle": "@user1",
            "message": "Hello world!",  # Duplicate
            "name": "User One",
            "hours_ago": 2.0
        }
    ]
    
    # Test each approach
    rds_results = rds.ingest_tweets(test_tweets)
    redis_results = redis.ingest_tweets(test_tweets)
    dynamo_results = dynamo.ingest_tweets(test_tweets)
    
    return {
        'rds': rds_results,
        'redis': redis_results,
        'dynamo': dynamo_results
    }
```

```python
import boto3
import time
from typing import List, Dict, Tuple
from dataclasses import dataclass
from botocore.exceptions import ClientError

@dataclass
class Tweet:
    handle: str
    message: str
    name: str
    hours_ago: float
    # Add any other fields you might want for ML

class MLDataCollector:
    def __init__(self, table_name: str, ttl_days: int = 90):
        self.dynamo = boto3.resource('dynamodb')
        self.table = self.dynamo.Table(table_name)
        self.ttl_days = ttl_days
    
    def store_tweets(self, tweets: List[Tweet]) -> Tuple[int, int]:
        successful = 0
        duplicates = 0
        
        with self.table.batch_writer() as batch:
            for tweet in tweets:
                try:
                    # Store with TTL for efficient cleanup
                    batch.put_item(
                        Item={
                            # Composite key for deduplication
                            'HandleMessage': f"{tweet.handle}#{tweet.message}",
                            
                            # Store all fields you'll need for ML
                            'Handle': tweet.handle,
                            'Message': tweet.message,
                            'Name': tweet.name,
                            'HoursAgo': tweet.hours_ago,
                            
                            # TTL field (auto-cleanup after N days)
                            'ExpiresAt': int(time.time() + (self.ttl_days * 86400)),
                            
                            # Timestamp for tracking data freshness
                            'CollectedAt': int(time.time())
                        },
                        ConditionExpression='attribute_not_exists(HandleMessage)'
                    )
                    successful += 1
                except ClientError as e:
                    if e.response['Error']['Code'] == 'ConditionalCheckFailedException':
                        duplicates += 1
                    else:
                        raise
        
        return successful, duplicates

    def export_for_training(self, start_time: int = None) -> List[Dict]:
        """Export all collected data for ML training"""
        items = []
        scan_kwargs = {
            'ProjectionExpression': 'Handle, Message, Name, HoursAgo'
        }
        
        if start_time:
            scan_kwargs['FilterExpression'] = 'CollectedAt >= :start_time'
            scan_kwargs['ExpressionAttributeValues'] = {':start_time': start_time}
        
        done = False
        start_key = None
        
        while not done:
            if start_key:
                scan_kwargs['ExclusiveStartKey'] = start_key
            
            response = self.table.scan(**scan_kwargs)
            items.extend(response.get('Items', []))
            
            start_key = response.get('LastEvaluatedKey', None)
            done = start_key is None
        
        return items

def create_table(table_name: str):
    """Create DynamoDB table for ML data collection"""
    dynamo = boto3.resource('dynamodb')
    
    table = dynamo.create_table(
        TableName=table_name,
        KeySchema=[
            {
                'AttributeName': 'HandleMessage',
                'KeyType': 'HASH'
            }
        ],
        AttributeDefinitions=[
            {
                'AttributeName': 'HandleMessage',
                'AttributeType': 'S'
            }
        ],
        BillingMode='PAY_PER_REQUEST',  # On-demand pricing
        TimeToLiveSpecification={
            'Enabled': True,
            'AttributeName': 'ExpiresAt'
        }
    )
    
    # Wait for table creation
    table.meta.client.get_waiter('table_exists').wait(TableName=table_name)
    return table

# Example usage
if __name__ == "__main__":
    collector = MLDataCollector('MLTweetCollection', ttl_days=90)
    
    # Example collecting tweets
    test_tweets = [
        Tweet("@user1", "Hello world!", "User One", 1.0),
        Tweet("@user1", "Hello world!", "User One", 2.0),  # Duplicate
        Tweet("@user2", "Different tweet", "User Two", 1.5)
    ]
    
    successful, dupes = collector.store_tweets(test_tweets)
    print(f"Stored {successful} tweets, found {dupes} duplicates")
    
    # Example exporting for training
    week_ago = int(time.time()) - (7 * 86400)
    training_data = collector.export_for_training(start_time=week_ago)
    print(f"Exported {len(training_data)} tweets for training")
```

```python
import boto3
import time
from typing import List, Dict, Optional, Set, Tuple
from dataclasses import dataclass
from datetime import datetime
import hashlib
import json

@dataclass
class Tweet:
    handle: str
    message: str
    name: str
    hours_ago: float

@dataclass
class DatasetVersion:
    version_id: str
    created_at: int
    description: str
    record_count: int
    schema_hash: str  # Hash of the data structure
    filters: dict     # What filters were applied
    
class MLDataVersioner:
    def __init__(self, data_table: str, version_table: str):
        self.dynamo = boto3.resource('dynamodb')
        self.data_table = self.dynamo.Table(data_table)
        self.version_table = self.dynamo.Table(version_table)
    
    def _compute_schema_hash(self, sample_record: Dict) -> str:
        """Create a hash of the data structure to track schema changes"""
        # Sort keys to ensure consistent hashing
        schema = sorted(sample_record.keys())
        return hashlib.sha256(json.dumps(schema).encode()).hexdigest()
    
    def create_version(self, description: str, filters: Optional[Dict] = None) -> str:
        """
        Create a new version of the dataset.
        Returns the version ID.
        """
        filters = filters or {}
        
        # Scan data table with filters
        scan_kwargs = {}
        if filters:
            # Convert filters to DynamoDB expression
            filter_expressions = []
            expr_values = {}
            
            for k, v in filters.items():
                filter_expressions.append(f"{k} = :val_{k}")
                expr_values[f":val_{k}"] = v
            
            scan_kwargs['FilterExpression'] = ' AND '.join(filter_expressions)
            scan_kwargs['ExpressionAttributeValues'] = expr_values
        
        # Count records and get schema
        record_count = 0
        schema_hash = None
        
        response = self.data_table.scan(**scan_kwargs)
        if response.get('Items'):
            schema_hash = self._compute_schema_hash(response['Items'][0])
            record_count = len(response['Items'])
        
        # Create version record
        version_id = f"v_{int(time.time())}"
        version = DatasetVersion(
            version_id=version_id,
            created_at=int(time.time()),
            description=description,
            record_count=record_count,
            schema_hash=schema_hash,
            filters=filters
        )
        
        # Store version metadata
        self.version_table.put_item(Item={
            'VersionId': version.version_id,
            'CreatedAt': version.created_at,
            'Description': version.description,
            'RecordCount': version.record_count,
            'SchemaHash': version.schema_hash,
            'Filters': version.filters
        })
        
        return version_id
    
    def get_version_data(self, version_id: str) -> Tuple[DatasetVersion, List[Dict]]:
        """Get version metadata and its associated data"""
        # Get version metadata
        version_response = self.version_table.get_item(
            Key={'VersionId': version_id}
        )
        if 'Item' not in version_response:
            raise ValueError(f"Version {version_id} not found")
        
        version = DatasetVersion(
            version_id=version_response['Item']['VersionId'],
            created_at=version_response['Item']['CreatedAt'],
            description=version_response['Item']['Description'],
            record_count=version_response['Item']['RecordCount'],
            schema_hash=version_response['Item']['SchemaHash'],
            filters=version_response['Item']['Filters']
        )
        
        # Get data using version filters
        scan_kwargs = {}
        if version.filters:
            filter_expressions = []
            expr_values = {}
            
            for k, v in version.filters.items():
                filter_expressions.append(f"{k} = :val_{k}")
                expr_values[f":val_{k}"] = v
            
            scan_kwargs['FilterExpression'] = ' AND '.join(filter_expressions)
            scan_kwargs['ExpressionAttributeValues'] = expr_values
        
        items = []
        done = False
        start_key = None
        
        while not done:
            if start_key:
                scan_kwargs['ExclusiveStartKey'] = start_key
            
            response = self.data_table.scan(**scan_kwargs)
            items.extend(response.get('Items', []))
            
            start_key = response.get('LastEvaluatedKey', None)
            done = start_key is None
        
        return version, items
    
    def list_versions(self) -> List[DatasetVersion]:
        """List all dataset versions"""
        response = self.version_table.scan()
        versions = []
        
        for item in response.get('Items', []):
            versions.append(DatasetVersion(
                version_id=item['VersionId'],
                created_at=item['CreatedAt'],
                description=item['Description'],
                record_count=item['RecordCount'],
                schema_hash=item['SchemaHash'],
                filters=item['Filters']
            ))
        
        return sorted(versions, key=lambda v: v.created_at, reverse=True)
    
    def compare_versions(self, version_id1: str, version_id2: str) -> Dict:
        """Compare two dataset versions"""
        v1, data1 = self.get_version_data(version_id1)
        v2, data2 = self.get_version_data(version_id2)
        
        return {
            'schema_changed': v1.schema_hash != v2.schema_hash,
            'size_diff': v2.record_count - v1.record_count,
            'filter_changes': {
                'added': {k: v for k, v in v2.filters.items() if k not in v1.filters},
                'removed': {k: v for k, v in v1.filters.items() if k not in v2.filters},
                'changed': {k: (v1.filters[k], v2.filters[k]) 
                           for k in v1.filters.keys() & v2.filters.keys() 
                           if v1.filters[k] != v2.filters[k]}
            }
        }

# Example usage
if __name__ == "__main__":
    versioner = MLDataVersioner('MLTweetData', 'MLDatasetVersions')
    
    # Create a version with all data
    full_version = versioner.create_version(
        description="Full dataset - December 2024"
    )
    
    # Create a filtered version
    filtered_version = versioner.create_version(
        description="English tweets only - December 2024",
        filters={'language': 'en'}
    )
    
    # List all versions
    versions = versioner.list_versions()
    for v in versions:
        print(f"Version {v.version_id}: {v.description}")
        print(f"  Created: {datetime.fromtimestamp(v.created_at)}")
        print(f"  Records: {v.record_count}")
        print(f"  Filters: {v.filters}\n")
    
    # Compare versions
    diff = versioner.compare_versions(full_version, filtered_version)
    print("Version comparison:", json.dumps(diff, indent=2))
```

```python
# Create versions for different experiments
v1 = versioner.create_version("Base dataset")
v2 = versioner.create_version("Filtered dataset", 
                             filters={'quality_score': {'gte': 0.8}})

# Track different preprocessing
v3 = versioner.create_version("Normalized text",
                             filters={'preprocessed': True})

# Create train/test splits
train_v = versioner.create_version("Training data 2024",
                                 filters={'split': 'train'})
test_v = versioner.create_version("Test data 2024",
                                filters={'split': 'test'})
```


---
## In-Memory HashMap


## Tutorial

```python
import hashlib
from typing import Dict, List, NamedTuple
from dataclasses import dataclass
from collections import defaultdict

@dataclass
class Tweet:
    name: str
    handle: str
    hours_ago: float
    message: str

class DedupSystem:
    def __init__(self):
        # Store message hashes for exact duplicates
        self.message_hashes: set = set()
        # Store cleaned message hashes for near-duplicates
        self.cleaned_message_hashes: set = set()
        
    def clean_message(self, message: str) -> str:
        """Normalize message by removing extra spaces, converting to lowercase"""
        return ' '.join(message.lower().split())
    
    def compute_hash(self, text: str) -> str:
        """Compute SHA-256 hash of text"""
        return hashlib.sha256(text.encode('utf-8')).hexdigest()
    
    def is_duplicate(self, tweet: Tweet) -> bool:
        """
        Check if a tweet is a duplicate using both exact and fuzzy matching.
        Returns True if duplicate found, False otherwise.
        """
        # Check exact message hash
        message_hash = self.compute_hash(tweet.message)
        if message_hash in self.message_hashes:
            return True
            
        # Check normalized message hash to catch near-duplicates
        cleaned_message = self.clean_message(tweet.message)
        cleaned_hash = self.compute_hash(cleaned_message)
        if cleaned_hash in self.cleaned_message_hashes:
            return True
            
        # If no duplicates found, add both hashes
        self.message_hashes.add(message_hash)
        self.cleaned_message_hashes.add(cleaned_hash)
        return False

def process_tweets(tweets: List[Tweet]) -> List[Tweet]:
    """Process a list of tweets and return only unique ones"""
    dedup = DedupSystem()
    unique_tweets = []
    
    for tweet in tweets:
        if not dedup.is_duplicate(tweet):
            unique_tweets.append(tweet)
            
    return unique_tweets

# Example usage
if __name__ == "__main__":
    sample_tweets = [
        Tweet("John Doe", "@johnd", 2, "Hello world!"),
        Tweet("Jane Smith", "@janes", 3, "Hello World!"),  # Near-duplicate
        Tweet("Bob Wilson", "@bobw", 1, "Hello world!"),   # Exact duplicate
        Tweet("Alice Brown", "@alice", 4, "Different message"),
    ]
    
    unique = process_tweets(sample_tweets)
    print(f"Original tweets: {len(sample_tweets)}")
    print(f"Unique tweets: {len(unique)}")
```

1. Dask cluster
1. Dask something like `dd.read_csv('s3://bucket/myfiles.*.csv')`
1. Use Dask for dedup or other ops

## Cost

1. $0.023 per GB for the first 50 TB.
1. We can avoid data processing charges by using an gateway type VPC endpoint for S3

Cost are about 100 times less than Elasticache.

But in this scenario we would alos need some additional EC2s for doing the processing work on our own.

See
[https://aws.amazon.com/s3/pricing/](https://aws.amazon.com/s3/pricing/)
for more details.

---
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
