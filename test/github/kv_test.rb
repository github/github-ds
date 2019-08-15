require "test_helper"

class GitHub::KVTest < Minitest::Test
  def setup
    ActiveRecord::Base.connection.execute("TRUNCATE `key_values`")
    @kv = GitHub::KV.new { ActiveRecord::Base.connection }
  end

  def test_initialize_without_connection
    kv = GitHub::KV.new
    assert_raises GitHub::KV::MissingConnectionError do
      kv.get("foo").value!
    end
  end

  def test_get_and_set
    assert_nil @kv.get("foo").value!

    @kv.set("foo", "bar")

    assert_equal "bar", @kv.get("foo").value!
  end

  def test_get_set_literal
    assert_nil @kv.get("foo").value!

    @kv.set("foo", GitHub::SQL::BINARY("bar"))

    assert_equal "bar", @kv.get("foo").value!
  end

  def test_mget_and_mset
    assert_equal [nil, nil], @kv.mget(["a", "b"]).value!

    @kv.mset("a" => "1", "b" => "2")

    assert_equal ["1", "2"], @kv.mget(["a", "b"]).value!
    assert_equal ["2", "1"], @kv.mget(["b", "a"]).value!
  end

  def test_get_failure
    ActiveRecord::Base.connection.stubs(:select_all).raises(Errno::ECONNRESET)

    result = @kv.get("foo")

    refute_predicate result, :ok?
  end

  def test_set_failure
    ActiveRecord::Base.connection.stubs(:insert).raises(Errno::ECONNRESET)

    assert_raises GitHub::KV::UnavailableError do
      @kv.set("foo", "bar")
    end
  end

  def test_increment_failure
    ActiveRecord::Base.connection.stubs(:insert).raises(Errno::ECONNRESET)

    assert_raises GitHub::KV::UnavailableError do
      @kv.increment("foo")
    end
  end

  def test_increment_default_value
    result = @kv.increment("foo")

    assert_equal 1, result
  end

  def test_increment_large_value
    result = @kv.increment("foo", amount: 10000)

    assert_equal 10000, result
  end

  def test_increment_negative
    result = @kv.increment("foo", amount: -1)

    assert_equal -1, result
  end

  def test_increment_negative_to_0
    @kv.set("foo", "1")
    result = @kv.increment("foo", amount: -1)

    assert_equal 0, result
  end

  def test_increment_multiple
    @kv.increment("foo")
    result = @kv.increment("foo")

    assert_equal 2, result
  end

  def test_increment_multiple_different_values
    @kv.increment("foo")
    result = @kv.increment("foo", amount: 2)

    assert_equal 3, result
  end

  def test_increment_existing
    @kv.set("foo", "1")

    result = @kv.increment("foo")

    assert_equal 2, result
  end

  def test_increment_overwrites_expired_value
    @kv.set("foo", "100", expires: 1.hour.ago)
    result = @kv.increment("foo")

    assert_equal 1, result
  end

  def test_increment_sets_expires
    expires = 2.hours.from_now.utc

    @kv.set("foo", "100", expires: 1.hour.from_now)
    @kv.increment("foo", expires: expires)

    assert_equal expires.to_i, @kv.ttl("foo").value!.to_i
  end

  def test_increment_updates_expires
    @kv.set("foo", "100", expires: 1.hour.ago)
    result = @kv.increment("foo")

    assert_equal 1, result
  end

  def test_increment_non_integer_key_value
    @kv.set("foo", "bar")

    assert_raises GitHub::KV::InvalidValueError do
      @kv.increment("foo")
    end
    assert_equal "bar", @kv.get("foo").value!
  end

  def test_increment_only_accepts_integer_amounts
    assert_raises ArgumentError do
      @kv.increment("foo", amount: "bar")
    end
  end

  def test_increment_only_accepts_integer_amounts
    assert_raises ArgumentError do
      @kv.increment("foo", amount: 0)
    end
  end

  def test_exists
    assert_equal false, @kv.exists("foo").value!

    @kv.set("foo", "bar")

    assert_equal true, @kv.exists("foo").value!
  end

  def test_mexists
    @kv.set("foo", "bar")

    assert_equal [true, false], @kv.mexists(["foo", "notfoo"]).value!
    assert_equal [false, true], @kv.mexists(["notfoo", "foo"]).value!
  end

  def test_setnx
    assert @kv.setnx("foo", "bar")
    refute @kv.setnx("foo", "nope")

    assert_equal "bar", @kv.get("foo").value!
  end

  def test_setnx_failure
    ActiveRecord::Base.connection.stubs(:delete).raises(Errno::ECONNRESET)

    assert_raises GitHub::KV::UnavailableError do
      @kv.setnx("foo", "bar")
    end
  end

  def test_del
    @kv.set("foo", "bar")
    @kv.del("foo")

    assert_nil @kv.get("foo").value!
  end

  def test_del_failure
    ActiveRecord::Base.connection.stubs(:delete).raises(Errno::ECONNRESET)

    assert_raises GitHub::KV::UnavailableError do
      @kv.del("foo")
    end
  end

  def test_mdel
    @kv.set("foo", "bar")
    @kv.mdel(["foo", "notfoo"])

    assert_nil @kv.get("foo").value!
    assert_nil @kv.get("notfoo").value!
  end

  def test_set_with_expiry
    # the Time.at dance is necessary because MySQL does not support sub-second
    # precision in DATETIME values
    expires = Time.at(1.hour.from_now.to_i).utc

    @kv.set("foo", "bar", expires: expires)

    assert_equal expires, GitHub::SQL.value(<<-SQL)
      SELECT expires_at FROM key_values WHERE `key` = 'foo'
    SQL
  end

  def test_setnx_with_expiry
    expires = Time.at(1.hour.from_now.to_i).utc

    @kv.setnx("foo", "bar", expires: expires)

    assert_equal expires, GitHub::SQL.value(<<-SQL)
      SELECT expires_at FROM key_values WHERE `key` = 'foo'
    SQL
  end

  def test_get_respects_expiry
    @kv.set("foo", "bar", expires: 1.hour.from_now)

    assert_equal "bar", @kv.get("foo").value!

    @kv.set("foo", "bar", expires: 1.hour.ago)

    assert_nil @kv.get("foo").value!
  end

  def test_exists_respects_expiry
    @kv.set("foo", "bar", expires: 1.hour.from_now)

    assert @kv.exists("foo").value!

    @kv.set("foo", "bar", expires: 1.hour.ago)

    refute @kv.exists("foo").value!
  end

  def test_set_resets_expiry
    @kv.set("foo", "bar", expires: 1.hour.from_now)
    @kv.set("foo", "bar")

    assert_nil GitHub::SQL.value(<<-SQL)
      SELECT expires_at FROM key_values WHERE `key` = "foo"
    SQL
  end

  def test_setnx_overwrites_expired_key
    @kv.set("foo", "bar", expires: 1.hour.ago)

    @kv.setnx("foo", "bar2")

    assert_equal "bar2", @kv.get("foo").value!
  end

  def test_ttl
    assert_nil @kv.ttl("foo-ttl").value!

    # the Time.at dance is necessary because MySQL does not support sub-second
    # precision in DATETIME values
    expires = Time.at(1.hour.from_now.to_i).utc
    @kv.set("foo-ttl", "bar", expires: expires)

    assert_equal expires, @kv.ttl("foo-ttl").value!
  end

  def test_ttl_for_key_that_exists_but_is_expired
    @kv.set("foo-ttl", "bar", expires: 1.hour.ago)

    row_count = GitHub::SQL.value <<-SQL, key: "foo-ttl"
      SELECT count(*) FROM key_values WHERE `key` = :key
    SQL
    assert_equal 1, row_count
    assert_nil @kv.ttl("foo-ttl").value!
  end

  def test_mttl
    assert_equal [nil, nil], @kv.mttl(["foo-ttl", "bar-ttl"]).value!

    # the Time.at dance is necessary because MySQL does not support sub-second
    # precision in DATETIME values
    expires = Time.at(1.hour.from_now.to_i).utc
    @kv.set("foo-ttl", "bar", expires: expires)

    assert_equal [expires, nil], @kv.mttl(["foo-ttl", "bar-ttl"]).value!
    assert_equal [nil, expires], @kv.mttl(["bar-ttl", "foo-ttl"]).value!
  end

  def test_type_checks_key
    assert_raises TypeError do
      @kv.get(0)
    end
  end

  def test_length_checks_key
    assert_raises GitHub::KV::KeyLengthError do
      @kv.get("A" * 256)
    end
  end

  def test_type_checks_value
    assert_raises TypeError do
      @kv.set("foo", 1)
    end
  end

  def test_length_checks_value
    assert_raises GitHub::KV::ValueLengthError do
      @kv.set("foo", "A" * 65536)
    end

    assert_raises GitHub::KV::ValueLengthError do
      @kv.set("foo", "💥" * 20000)
    end
  end

  def test_timecop
    with_local_time do
      Timecop.freeze(1.month.ago) do
        # setnx - currently unset
        @kv.setnx("foo", "asdf", expires: 1.day.from_now.utc)
        assert_equal "asdf", @kv.get("foo").value!

        # setnx - currently expired
        @kv.set("foo", "bar", expires: 1.day.ago.utc)
        @kv.setnx("foo", "asdf", expires: 1.day.from_now.utc)
        assert_equal "asdf", @kv.get("foo").value!

        # set/get
        @kv.set("foo", "bar", expires: 1.day.from_now.utc)
        assert_equal "bar", @kv.get("foo").value!

        # exists
        assert_equal true, @kv.exists("foo").value!

        # ttl
        assert_equal 1.day.from_now.to_i, @kv.ttl("foo").value!.to_i

        # mset/mget
        @kv.mset({"foo" => "baz"}, expires: 1.day.from_now.utc)
        assert_equal ["baz"], @kv.mget(["foo"]).value!

        # increment
        @kv.increment("foo-increment", expires: 1.day.from_now.utc)
        assert_equal 1, @kv.get("foo-increment").value!.to_i
      end
    end
  end

  def with_local_time(&blk)
    use_local_time_was = @kv.use_local_time
    @kv.use_local_time = true
    blk.call
  ensure
    @kv.use_local_time = use_local_time_was
  end
end
