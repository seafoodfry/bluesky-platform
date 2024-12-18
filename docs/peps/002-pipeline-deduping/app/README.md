# Valkey Sandbox

To spin up a valkey server and a client with the valkey CLI installed run:
```
make valkey
```

To send requests to the server we need to figure out its IP
```
$ docker inspect -f '{{range.NetworkSettings.Networks}}{{.IPAddress}}{{end}}' valkey-server
172.18.0.2
```

We can test the connection playing ping pong:
```
$ valkey-cli -h 172.18.0.2 PING
PONG
```

To start an interactive shell run:
```
# valkey-cli -h 172.18.0.2     
172.18.0.2:6379> 
```

To increase a counter:
```
root@262b0071da20:/data# valkey-cli -h 172.18.0.2 INCR counter
(integer) 1
root@262b0071da20:/data# valkey-cli -h 172.18.0.2 INCR counter
(integer) 2
root@262b0071da20:/data# valkey-cli -h 172.18.0.2 INCR counter
(integer) 3
```

To set and retrieve a string:
```
172.18.0.2:6379> SET bike:1 "process 134" 
OK

172.18.0.2:6379> GET bike:1
"process 134"
```

You can implicitly store key-value pairs within a single entry:
```
172.18.0.2:6379> HSET cpu:amd year 2025 price 999 description "very hip"
(integer) 3

172.18.0.2:6379> HGETALL cpu:amd
1) "year"
2) "2025"
3) "price"
4) "999"
5) "description"
6) "very hip"

172.18.0.2:6379> HGET cpu:amd price
"999"
172.18.0.2:6379> HINCRBY cpu:amd price 1
(integer) 1000
172.18.0.2:6379> HGET cpu:amd price
"1000"

172.18.0.2:6379> HMGET cpu:amd year price description
1) "2025"
2) "1000"
3) "very hip"

172.18.0.2:6379> HEXISTS cpu:amd price
(integer) 1
172.18.0.2:6379> HEXISTS cpu:amd pricee
(integer) 0

172.18.0.2:6379> EXPIRE cpu:amd 60
(integer) 1
172.18.0.2:6379> HGETALL cpu:amd
(empty array)

172.18.0.2:6379> KEYS *
1) "counter"
2) "bike:1"

172.18.0.2:6379> SCAN 0
1) "0"
2) 1) "bike:1"
   2) "counter"
172.18.0.2:6379> SCAN 0 MATCH *
1) "0"
2) 1) "bike:1"
   2) "counter"
```



See
[valkey.io/commands](https://valkey.io/commands/)
and
[redis.io/commands](https://redis.io/docs/latest/commands/)
for more details.