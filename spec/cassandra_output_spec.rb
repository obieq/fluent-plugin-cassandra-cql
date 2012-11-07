require 'spec_helper'
Fluent::Test.setup

CONFIG = %[
  host 127.0.0.1
  port 9160
  keyspace FluentdLoggers
  columnfamily events
]

describe Fluent::CassandraOutput do
  let(:driver) { Fluent::Test::BufferedOutputTestDriver.new(Fluent::CassandraOutput, 'test') }

  after(:each) do
    d = Fluent::Test::BufferedOutputTestDriver.new(Fluent::CassandraOutput, 'test')
    d.configure(CONFIG)
    d.instance.connection.execute("TRUNCATE events")
  end

  def add_ttl_to_config(ttl)
    return CONFIG + %[  ttl #{ttl}\n]
  end

  context 'configuring' do

    it 'should be properly configured' do
      driver.configure(CONFIG)
      driver.tag.should eq('test')
      driver.instance.host.should eq('127.0.0.1')
      driver.instance.port.should eq(9160)
      driver.instance.keyspace.should eq('FluentdLoggers')
      driver.instance.columnfamily.should eq('events')
      driver.instance.ttl.should eq(0)
    end

    it 'should configure ttl' do
      ttl = 20
      driver.configure(add_ttl_to_config(ttl))
      driver.instance.ttl.should eq(ttl)
    end

    describe 'exceptions' do

      it 'should raise an exception if host is not configured' do
        expect { driver.configure(CONFIG.gsub("host", "invalid_config_name")) }.to raise_error Fluent::ConfigError
      end

      it 'should raise an exception if port is not configured' do
        expect { driver.configure(CONFIG.gsub("port", "invalid_config_name")) }.to raise_error Fluent::ConfigError
      end

      it 'should raise an exception if keyspace is not configured' do
        expect { driver.configure(CONFIG.gsub("keyspace", "invalid_config_name")) }.to raise_error Fluent::ConfigError
      end

      it 'should raise an exception if columnfamily is not configured' do
        expect { driver.configure(CONFIG.gsub("columnfamily", "invalid_config_name")) }.to raise_error Fluent::ConfigError
      end

    end

  end

  context 'fluentd logging' do

    it 'should start' do
      driver.configure(CONFIG)
      driver.instance.start
    end

    it 'should shutdown' do
      driver.configure(CONFIG)
      driver.instance.start
      driver.instance.shutdown
    end

    it 'should format' do
      driver.configure(CONFIG)
      time = Time.now.to_i
      record = {'tag' => 'test', 'time' => time, 'a' => 1}

      driver.emit(record)
      driver.expect_format(record.to_msgpack)
      driver.run
    end

    it 'should write' do
      driver.configure(CONFIG)
      tag1 = "test1"
      tag2 = "test2"
      time1 = Time.now.to_i
      time2 = Time.now.to_i + 2
      record1 = {'tag' => tag1, 'time' => time1, 'a' => 10, 'b' => 'Tesla'}
      record2 = {'tag' => tag2, 'time' => time2, 'a' => 20, 'b' => 'Edison'}
      records = [record1, record2]

      driver.emit(records[0])
      driver.emit(records[1])
      driver.run # persists to cassandra

      # query cassandra to verify data was correctly persisted
      row_num = records.count # non-zero based index
      events = driver.instance.connection.execute("SELECT * FROM events")
      events.rows.should eq(records.count)
      events.fetch do | event | # events should be sorted desc by tag, then time
        row_num -= 1 # zero-based index
        hash = event.to_hash
        hash['id'].should eq(records[row_num]['tag'])
        hash['ts'].should eq(records[row_num]['time'])
        hash['payload'].should eq(records[row_num].to_json)
      end
    end

    it 'should not locate event after ttl has expired' do
      time = Time.now.to_i
      tag = "ttl_test"
      ttl = 1 # set ttl to 1 second

      driver.configure(add_ttl_to_config(ttl))
      driver.emit({'tag' => tag, 'time' => time, 'a' => 1})
      driver.run

      # verify record... should return in less than one sec if hitting
      #                  cassandra running on localhost
      events = driver.instance.connection.execute("SELECT * FROM events where ts = #{time}")
      events.rows.should eq(1)

      # now, sleep long enough for the event to be expired from cassandra
      sleep(ttl)

      # re-query and verify that no events were returned
      events = driver.instance.connection.execute("SELECT * FROM events where ts = #{time}")
      events.rows.should eq(0)
    end

  end

end # CassandraOutput
