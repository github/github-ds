require "test_helper"

class GitHub::Data::KVTest < Minitest::Test
  def setup
    ActiveRecord::Base.connection.execute("TRUNCATE `key_values`")
    @kv = GitHub::Data::KV.new { ActiveRecord::Base.connection }
  end

  def test_initialize_without_connection
    kv = GitHub::Data::KV.new
    assert_raises GitHub::Data::KV::MissingConnectionError do
      kv.get("foo").value!
    end
  end

  def test_get_and_set
    assert_nil @kv.get("foo").value!

    @kv.set("foo", "bar")

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

    assert_raises GitHub::Data::KV::UnavailableError do
      @kv.set("foo", "bar")
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

    assert_raises GitHub::Data::KV::UnavailableError do
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

    assert_raises GitHub::Data::KV::UnavailableError do
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

    assert_equal expires, GitHub::Data::SQL.value(<<-SQL)
      SELECT expires_at FROM key_values WHERE `key` = 'foo'
    SQL
  end

  def test_setnx_with_expiry
    expires = Time.at(1.hour.from_now.to_i).utc

    @kv.setnx("foo", "bar", expires: expires)

    assert_equal expires, GitHub::Data::SQL.value(<<-SQL)
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

    assert_nil GitHub::Data::SQL.value(<<-SQL)
      SELECT expires_at FROM key_values WHERE `key` = "foo"
    SQL
  end

  def test_setnx_overwrites_expired_key
    @kv.set("foo", "bar", expires: 1.hour.ago)

    @kv.setnx("foo", "bar2")

    assert_equal "bar2", @kv.get("foo").value!
  end

  def test_type_checks_key
    assert_raises TypeError do
      @kv.get(0)
    end
  end

  def test_length_checks_key
    assert_raises GitHub::Data::KV::KeyLengthError do
      @kv.get("A" * 256)
    end
  end

  def test_type_checks_value
    assert_raises TypeError do
      @kv.set("foo", 1)
    end
  end

  def test_length_checks_value
    assert_raises GitHub::Data::KV::ValueLengthError do
      @kv.set("foo", "A" * 65536)
    end
  end
end
