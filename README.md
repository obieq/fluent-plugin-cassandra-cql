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

    fluent-gem install fluent-plugin-cassandra-cql

# Quick Start

## Cassandra Configuration
    # create keyspace (via CQL)
    cqlsh>  CREATE KEYSPACE "FluentdLoggers" WITH REPLICATION = { 'class' : 'SimpleStrategy', 'replication_factor' : 1};

    cqlsh> USE "FluentdLoggers";
    # create table (column family)
    cqlsh>  CREATE TABLE spec_events (id varchar, ts bigint, payload text, PRIMARY KEY (id, ts)) WITH CLUSTERING ORDER BY (ts DESC);

    # NOTE: schema definition should match that specified in the Fluentd.conf configuration file (see below)

## Fluentd.conf Configuration
    <match cassandra_cql.**>
      type cassandra_cql         # fluent output plugin file name (sans fluent_plugin_ prefix)
      host 127.0.0.1             # cassandra hostname.
      port 9042                  # cassandra port.
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
    3) support multiple ip addresses in the connection string for Cassandra multi-node environments
    4) make the cql version configurable
