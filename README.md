# Cassandra plugin for Fluentd

Cassandra output plugin for Fluentd.

Implemented using the cassandra-cql gem and targets [CQL 3.0.0](http://www.datastax.com/docs/1.1/references/cql/index)
and Cassandra 1.1.x

# Raison d'être
Currently, there's another [Fluentd Cassandra plugin](https://github.com/tomitakazutaka/fluent-plugin-cassandra)

It's implemented via the Twitter Cassandra gem, which:

    a) doesn't provide all of the niceties of CQL, i.e., create/alter/delete keyspaces/columnfamilies
    b) doesn't allow a desktop client to make a call to a Cassandra instance hosted on EC2
       (the gem resolves a cassandra node's IP address to its private EC2
        IP address (ex: 10.x.x.x), which isn't accessible outside EC2)

# Installation

via RubyGems

    gem install fluent-plugin-cassandra-cql

# Quick Start

## Cassandra Configuration
    # create keyspace (via CQL)
      CREATE KEYSPACE \"FluentdLoggers\" WITH strategy_class='org.apache.cassandra.locator.SimpleStrategy' AND strategy_options:replication_factor=1;

    # create table (column family)
      CREATE TABLE events (id varchar, ts bigint, payload text, PRIMARY KEY (id, ts)) WITH CLUSTERING ORDER BY (ts DESC);

    # NOTE: schema definition should match that specified in the Fluentd.conf configuration file

## Fluentd.conf Configuration
    <match cassandra.**>
      type cassandra
      host 127.0.0.1             # cassandra hostname.
      port 9160                  # cassandra thrft port.
      keyspace FluentdLoggers    # cassandra keyspace
      columnfamily spec_events   # cassandra column family
      ttl 60                     # cassandra ttl *optional => default is 0*
      schema                     # cassandra column family schema *hash where keys => column names and values => data types*
      data_keys                  # comma delimited string of the fluentd hash's keys
      pop_data_keys              # keep or pop key/values from the fluentd hash when storing it as json
    </match>

# Tests

rake rspec

    NOTE: requires that cassandra be installed on the machine running the
          test as well as a keyspace named "FluentdLoggers" and a column family
          named "spec_events"

# TODOs
    1) make host and port configurable for tests
    2) add rake task to generate keyspace and columnfamily
