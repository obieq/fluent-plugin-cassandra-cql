require 'cassandra-cql'
require 'msgpack'
require 'json'

module Fluent

  class CassandraOutput < BufferedOutput
    Fluent::Plugin.register_output('cassandra-cql', self)

    config_param :host,          :string
    config_param :port,          :integer
    config_param :keyspace,      :string
    config_param :columnfamily,  :string
    config_param :ttl,           :integer, :default => 0
    config_param :schema,        :string
    config_param :data_keys,     :string

    # remove keys from the fluentd json event as they're processed
    # for individual columns?
    config_param :pop_data_keys, :bool, :default => true

    def connection
      @connection ||= get_connection(self.host, self.port, self.keyspace)
    end

    def configure(conf)
      super

      # perform validations
      raise ConfigError, "'Host' is required by Cassandra output (ex: localhost, 127.0.0.1, ec2-54-242-141-252.compute-1.amazonaws.com" if self.host.nil?
      raise ConfigError, "'Port' is required by Cassandra output (ex: 9160)" if self.port.nil?
      raise ConfigError, "'Keyspace' is required by Cassandra output (ex: FluentdLoggers)" if self.keyspace.nil?
      raise ConfigError, "'ColumnFamily' is required by Cassandra output (ex: events)" if self.columnfamily.nil?
      raise ConfigError, "'Schema' is required by Cassandra output (ex: id,ts,payload)" if self.schema.nil?
      raise ConfigError, "'Schema' must contain at least two column names (ex: id,ts,payload)" if self.schema.split(',').count < 2
      raise ConfigError, "'DataKeys' is required by Cassandra output (ex: tag,created_at,data)" if self.data_keys.nil?

      # convert schema from string to hash
      # NOTE: ok to use eval b/c this isn't this isn't a user
      #       supplied string
      self.schema = eval(self.schema)

      # convert data keys from string to array
      self.data_keys = self.data_keys.split(',')
    end

    def start
      super
      connection
    end

    def shutdown
      super
    end

    def format(tag, time, record)
      record.to_msgpack
    end

    def write(chunk)
      chunk.msgpack_each  { |record|
        values = build_insert_values_string(self.schema.keys, self.data_keys, record, self.pop_data_keys)
        cql = "INSERT INTO #{self.columnfamily} (#{self.schema.keys.join(',')}) " +
                            "VALUES (#{values}) " +
                            "USING TTL #{self.ttl}"
        @connection.execute(cql)
      }
    end

    private

    def get_connection(host, port, keyspace)
      connection_string = "#{host}:#{port}"
      ::CassandraCQL::Database.new(connection_string, {:keyspace => "\"#{keyspace}\"", :cql_version => "3.0.0"})
    end

    def build_insert_values_string(schema_keys, data_keys, record, pop_data_keys)
      values = data_keys.map.with_index do |key, index|
        if pop_data_keys
          schema[schema_keys[index]] == :string ? "'#{record.delete(key)}'" : record.delete(key)
        else
          schema[schema_keys[index]] == :string ? "'#{record[key]}'" : record[key]
        end
      end

      # if we have one more schema key than data keys,
      # we can then infer that we should store the event
      # as a string representation of the corresponding
      # json object in the last schema column
      if schema_keys.count == data_keys.count + 1
        values << if record.count > 0
                    "'#{record.to_json}'"
                  else
                    # by this point, the extra schema column has been
                    # added to insert cql statement, so we must put
                    # something in it
                    # TODO: detect this scenario earlier and don't
                    #       specify the column name/value at all
                    #       when constructing the cql stmt
                    "''"
                  end
      end

      return values.join(',')
    end

  end

end
