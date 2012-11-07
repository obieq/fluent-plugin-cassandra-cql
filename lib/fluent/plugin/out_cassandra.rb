require 'cassandra-cql'
require 'msgpack'
require 'json'

module Fluent

  class CassandraOutput < BufferedOutput
    Fluent::Plugin.register_output('cassandra', self)
    include SetTimeKeyMixin
    include SetTagKeyMixin

    config_param :host,         :string
    config_param :port,         :integer
    config_param :keyspace,     :string
    config_param :columnfamily, :string
    config_param :ttl,          :integer, :default => 0

    def connection
      @connection ||= get_connection
    end

    #config_set_default :include_time_key, true
    #config_set_default :include_tag_key, true
    #config_set_default :time_format, "%Y%m%d%H%M%S"

    def configure(conf)
      super

      raise ConfigError, "'Host' is required by Cassandra output (ex: localhost, 127.0.0.1, ec2-54-242-141-252.compute-1.amazonaws.com" unless self.keyspace = conf['keyspace']
      raise ConfigError, "'Port' is required by Cassandra output (ex: 9160)" unless self.columnfamily = conf['columnfamily']
      raise ConfigError, "'Keyspace' is required by Cassandra output (ex: FluentdLoggers)" unless self.keyspace = conf['keyspace']
      raise ConfigError, "'ColumnFamily' is required by Cassandra output (ex: events)" unless self.columnfamily = conf['columnfamily']

      #@host = conf.has_key?('host') ? conf['host'] : 'localhost'
      #@port = conf.has_key?('port') ? conf['port'] : 9160
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
        @connection.execute("INSERT INTO #{self.columnfamily} (id, ts, payload) " +
                            "VALUES ('#{record['tag']}', #{record['time']}, '#{record.to_json}') " +
                            "USING TTL #{self.ttl}")
      }
    end

    private

    def get_connection
      connection_string = "#{self.host}:#{self.port}"
      ::CassandraCQL::Database.new(connection_string, {:keyspace => "\"#{self.keyspace}\"", :cql_version => "3.0.0"})
    end

  end

end
