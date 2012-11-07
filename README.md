# Cassandra plugin for Fluentd

Cassandra output plugin for Fluentd.

Implemented using the cassandra-cql gem and targets CQL version 3.0.0

# Raison d'être
Currently, there's another Fluentd Cassandra plugin [see
here](https://github.com/tomitakazutaka/fluent-plugin-cassandra)

It's implemented via the Twitter Cassandra gem, which:
     a) doesn't provide all of the niceties of CQL, i.e., create/alter/delete keyspaces/columnfamilies
     b) doesn't allow a desktop client to make a call to a Cassandra instance hosted on EC2
        (the gem resolves a cassandra node's IP address to its private EC2
         IP address (ex: 10.x.x.x), which isn't accessible outside EC2)

# Quick Start

## Configuration
    # fluentd.conf
      <match cassandra.**>
        type cassandra
        host ec2-54-242-143-253.compute-1.amazonaws.com            # cassandra's hostname. default localhost
        port 9160                                                  # cassandra's thrft port. default 9160
        keyspace FluentdLoggers                                    # cassandra keyspace
        columnfamily events                                        # cassandra column family
      </match>

# TODOs
