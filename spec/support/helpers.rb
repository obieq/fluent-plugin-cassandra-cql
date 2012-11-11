module Helpers
  
  def write(driver, column_family_name, tag_and_time_only)
    tag1 = "test1"
    tag2 = "test2"
    time1 = Time.now.to_i
    time2 = Time.now.to_i + 2

    record1 = {'tag' => tag1, 'time' => time1}
    record2 = {'tag' => tag2, 'time' => time2}

    unless tag_and_time_only
      record1.merge!({'a' => 10, 'b' => 'Tesla'})
      record2.merge!({'a' => 20, 'b' => 'Edison'})
    end

    # store both records in an array
    records = [record1, record2]

    driver.emit(records[0])
    driver.emit(records[1])
    driver.run # persists to cassandra

    # query cassandra to verify data was correctly persisted
    row_num = records.count # non-zero based index
    events = driver.instance.connection.execute("SELECT * FROM #{column_family_name}")
    events.rows.should eq(records.count)
    events.fetch do | event | # events should be sorted desc by tag, then time
      row_num -= 1 # zero-based index

      record = records[row_num]
      db_hash = event.to_hash

      # need to take in account that we've popped both tag and time
      # from the payload data when we saved it
      if driver.instance.pop_data_keys
        db_hash['id'].should eq(record.delete('tag'))
        db_hash['ts'].should eq(record.delete('time'))
      else
        db_hash['id'].should eq(record['tag'])
        db_hash['ts'].should eq(record['time'])
      end

      if driver.instance.schema.keys.count == driver.instance.data_keys.count + 1 # store as json
        if record.count > 0
          db_hash['payload'].should eq(record.to_json)
        else
          db_hash['payload'].should eq('')
        end
      else
        db_hash['payload'].should eq(record[record.keys[db_hash.keys.index('payload')]])
      end
    end
  end

end
