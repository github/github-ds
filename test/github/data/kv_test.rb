require "test_helper"

class GitHub::Data::KVTest < Minitest::Test
  def self.test(name, &block)
    define_method("test_#{name.gsub(/\W/, '_')}", &block)
  end

  def setup
    ActiveRecord::Base.connection.execute("TRUNCATE `key_values`")
    @kv = GitHub::Data::KV.new { ActiveRecord::Base.connection }
  end

  test "kv without a connection" do
    kv = GitHub::Data::KV.new
    assert_raises GitHub::Data::KV::MissingConnectionError do
      kv.get("foo").value!
    end
  end

  test "get and set" do
    assert_nil @kv.get("foo").value!

    @kv.set("foo", "bar")

    assert_equal "bar", @kv.get("foo").value!
  end

  test "mget and mset" do
    assert_equal [nil, nil], @kv.mget(["a", "b"]).value!

    @kv.mset("a" => "1", "b" => "2")

    assert_equal ["1", "2"], @kv.mget(["a", "b"]).value!
    assert_equal ["2", "1"], @kv.mget(["b", "a"]).value!
  end

  test "get failure" do
    ActiveRecord::Base.connection.stubs(:select_all).raises(Errno::ECONNRESET)

    result = @kv.get("foo")

    refute_predicate result, :ok?
  end

  test "set failure" do
    ActiveRecord::Base.connection.stubs(:insert).raises(Errno::ECONNRESET)

    assert_raises GitHub::Data::KV::UnavailableError do
      @kv.set("foo", "bar")
    end
  end

  test "exists" do
    assert_equal false, @kv.exists("foo").value!

    @kv.set("foo", "bar")

    assert_equal true, @kv.exists("foo").value!
  end

  test "mexists" do
    @kv.set("foo", "bar")

    assert_equal [true, false], @kv.mexists(["foo", "notfoo"]).value!
    assert_equal [false, true], @kv.mexists(["notfoo", "foo"]).value!
  end

  test "setnx" do
    assert @kv.setnx("foo", "bar")
    refute @kv.setnx("foo", "nope")

    assert_equal "bar", @kv.get("foo").value!
  end

  test "setnx failure" do
    ActiveRecord::Base.connection.stubs(:delete).raises(Errno::ECONNRESET)

    assert_raises GitHub::Data::KV::UnavailableError do
      @kv.setnx("foo", "bar")
    end
  end

  test "del" do
    @kv.set("foo", "bar")
    @kv.del("foo")

    assert_nil @kv.get("foo").value!
  end

  test "del failure" do
    ActiveRecord::Base.connection.stubs(:delete).raises(Errno::ECONNRESET)

    assert_raises GitHub::Data::KV::UnavailableError do
      @kv.del("foo")
    end
  end

  test "mdel" do
    @kv.set("foo", "bar")
    @kv.mdel(["foo", "notfoo"])

    assert_nil @kv.get("foo").value!
    assert_nil @kv.get("notfoo").value!
  end

  test "set with expiry" do
    # the Time.at dance is necessary because MySQL does not support sub-second
    # precision in DATETIME values
    expires = Time.at(1.hour.from_now.to_i).utc

    @kv.set("foo", "bar", expires: expires)

    assert_equal expires, GitHub::Data::SQL.value(<<-SQL)
      SELECT expires_at FROM key_values WHERE `key` = 'foo'
    SQL
  end

  test "setnx with expiry" do
    expires = Time.at(1.hour.from_now.to_i).utc

    @kv.setnx("foo", "bar", expires: expires)

    assert_equal expires, GitHub::Data::SQL.value(<<-SQL)
      SELECT expires_at FROM key_values WHERE `key` = 'foo'
    SQL
  end

  test "get respects expiry" do
    @kv.set("foo", "bar", expires: 1.hour.from_now)

    assert_equal "bar", @kv.get("foo").value!

    @kv.set("foo", "bar", expires: 1.hour.ago)

    assert_nil @kv.get("foo").value!
  end

  test "exists respects expiry" do
    @kv.set("foo", "bar", expires: 1.hour.from_now)

    assert @kv.exists("foo").value!

    @kv.set("foo", "bar", expires: 1.hour.ago)

    refute @kv.exists("foo").value!
  end

  test "set resets expiry" do
    @kv.set("foo", "bar", expires: 1.hour.from_now)
    @kv.set("foo", "bar")

    assert_nil GitHub::Data::SQL.value(<<-SQL)
      SELECT expires_at FROM key_values WHERE `key` = "foo"
    SQL
  end

  test "setnx overwrites expired key" do
    @kv.set("foo", "bar", expires: 1.hour.ago)

    @kv.setnx("foo", "bar2")

    assert_equal "bar2", @kv.get("foo").value!
  end

  test "type checks key" do
    assert_raises TypeError do
      @kv.get(0)
    end
  end

  test "length checks key" do
    assert_raises GitHub::Data::KV::KeyLengthError do
      @kv.get("A" * 256)
    end
  end

  test "type checks value" do
    assert_raises TypeError do
      @kv.set("foo", 1)
    end
  end

  test "length checks value" do
    assert_raises GitHub::Data::KV::ValueLengthError do
      @kv.set("foo", "A" * 65536)
    end
  end
end
