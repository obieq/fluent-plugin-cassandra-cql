require 'spec_helper'
Fluent::Test.setup

SPEC_COLUMN_FAMILY = "spec_events"
DATA_KEYS = "tag,time"

CONFIG = %[
  host 127.0.0.1
  port 9042
  keyspace FluentdLoggers
  columnfamily #{SPEC_COLUMN_FAMILY}
  ttl 0
  schema {:id => :string, :ts => :bigint, :payload => :string}
  data_keys #{DATA_KEYS}
  pop_data_keys true
]

describe Fluent::CassandraCqlOutput do
  include Helpers

  let(:driver) { Fluent::Test::BufferedOutputTestDriver.new(Fluent::CassandraCqlOutput, 'test') }

  after(:each) do
    d = Fluent::Test::BufferedOutputTestDriver.new(Fluent::CassandraCqlOutput, 'test')
    d.configure(CONFIG)
    d.instance.session.execute("TRUNCATE #{SPEC_COLUMN_FAMILY}")
  end

  def set_config_value(config, config_name, value)
    search_text = config.split("\n").map {|text| text if text.strip!.to_s.start_with? config_name.to_s}.compact![0]
    config.gsub(search_text, "#{config_name} #{value}")
  end

  context 'configuring' do

    it 'should be properly configured' do
      driver.configure(CONFIG)
      driver.tag.should eq('test')
      driver.instance.host.should eq('127.0.0.1')
      driver.instance.port.should eq(9042)
      driver.instance.keyspace.should eq('FluentdLoggers')
      driver.instance.columnfamily.should eq(SPEC_COLUMN_FAMILY)
      driver.instance.ttl.should eq(0)
    end

    it 'should configure ttl' do
      ttl = 20
      driver.configure(set_config_value(CONFIG, :ttl, ttl))
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

  end # context configuring

  context 'logging' do

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

    context 'writing' do
      context 'as json' do

        describe 'pop no data keys' do
          it 'should store json in last column' do
            driver.configure(set_config_value(CONFIG, :pop_data_keys, false))
            write(driver, SPEC_COLUMN_FAMILY, false)
          end
        end

        describe 'pop some data keys' do
          it 'should store json in last last column' do
            driver.configure(set_config_value(CONFIG, :pop_data_keys, true))
            write(driver, SPEC_COLUMN_FAMILY, false)
          end
        end

        describe 'pop all data keys' do
          it 'should store empty string in last column' do
            driver.configure(CONFIG)
            write(driver, SPEC_COLUMN_FAMILY, true)
          end
        end

      end # context as json

      context 'as columns' do # no need to test popping of keys b/c it makes no difference

        it 'should write' do
          config = set_config_value(CONFIG, :data_keys, DATA_KEYS + ',a')
          config = set_config_value(CONFIG, :pop_data_keys, false)
          driver.configure(config)
          write(driver, SPEC_COLUMN_FAMILY, false)
        end

      end # context as columns

      it 'should not locate event after ttl has expired' do
        time = Time.now.to_i
        tag = "ttl_test"
        ttl = 1 # set ttl to 1 second

        driver.configure(set_config_value(CONFIG, :ttl, ttl))
        driver.emit({'tag' => tag, 'time' => time, 'a' => 1})
        driver.run

        # verify record... should return in less than one sec if hitting
        #                  cassandra running on localhost
        events = driver.instance.session.execute("SELECT * FROM #{SPEC_COLUMN_FAMILY} where ts = #{time} ALLOW FILTERING")
        events.rows.size.should eq(1)

        # now, sleep long enough for the event to be expired from cassandra
        sleep(ttl + 1)

        # re-query and verify that no events were returned
        events = driver.instance.session.execute("SELECT * FROM #{SPEC_COLUMN_FAMILY} where ts = #{time} ALLOW FILTERING")
        events.rows.size.should eq(0)
      end

    end # context writing

  end # context logging

end # CassandraOutput
