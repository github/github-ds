require "test_helper"
require "timecop"

ActiveRecord::Migration.verbose = false
ActiveRecord::Base.establish_connection({
  adapter: "mysql2",
  database: "github_data_test",
})

class GitHub::Data::SQLTest < Minitest::Test
  def self.test(name, &block)
    define_method("test_#{name.gsub(/\W/, '_')}", &block)
  end

  local_time = Time.new(1970, 1, 1, 0, 0, 0)

  Timecop.freeze(local_time) do
    foo = GitHub::Data::SQL::LITERAL "foo"
    rows = GitHub::Data::SQL::ROWS [[1, 2], [3, 4]]
    SANITIZE_TESTS = [
      [GitHub::Data::SQL,    "'GitHub::Data::SQL'"],
      [DateTime.now.utc,     "'1970-01-01 00:00:00'"],
      [Time.now.utc,         "'1970-01-01 00:00:00'"],
      [Time.now.utc.to_date, "'1970-01-01'"],
      [true,                 "1"],
      [false,                "0"],
      [17,                   "17"],
      [1.7,                  "1.7"],
      ["corge",              "'corge'"],
      [:frumple,             "'frumple'"],
      [foo,                  "foo"],
      [[1, 2],               "(1, 2)"],
      [rows,                 "(1, 2), (3, 4)"], # bulk inserts
    ]

    BAD_VALUE_TESTS = [
      Hash.new,
      nil,
      [],
      [1, 2, nil],
      [[1], [nil]],
      [[1, 2], [3, 4]]
    ]
  end

  SANITIZE_TESTS.each do |input, expected|
    test "#{input.inspect} sanitizes as #{expected.inspect}" do
      assert_equal expected, GitHub::Data::SQL.new.sanitize(input)
    end
  end

  BAD_VALUE_TESTS.each do |input|
    test "#{input.inspect} (#{input.class}) raises BadValue when sanitized" do
      assert_raises GitHub::Data::SQL::BadValue do
        GitHub::Data::SQL.new.sanitize input
      end
    end
  end

  test "initialize with SQL string" do
    str = "query"
    sql = GitHub::Data::SQL.new str

    assert_equal Hash.new, sql.binds
    assert_equal str, sql.query
    refute_same sql.query, str
  end

  test "initialize with binds" do
    binds = { :key => "value" }
    sql = GitHub::Data::SQL.new binds

    assert_equal "", sql.query
    assert_equal "value", sql.binds[:key]
    refute_same sql.binds, binds
  end

  test "initialize with query and binds" do
    sql = GitHub::Data::SQL.new "query :key", :key => "value"

    assert_equal "query 'value'", sql.query
    assert_equal "value", sql.binds[:key]
  end

  test "initialize with single-character binds" do
    sql = GitHub::Data::SQL.new "query :x", :x => "y"
    assert_equal "query 'y'", sql.query
    assert_equal "y", sql.binds[:x]
  end

  test "add SQL" do
    sql = GitHub::Data::SQL.new

    sql.add("first").add "second"
    assert_equal "first second", sql.query
  end

  test "add SQL with local binds" do
    sql = GitHub::Data::SQL.new

    sql.add ":local", :local => "value"
    assert_equal "'value'", sql.query

    assert_raises GitHub::Data::SQL::BadBind do
      sql.add ":local" # the previous value doesn't persist
    end
  end

  test "add SQL with leading and trailing whitespace" do
    sql = GitHub::Data::SQL.new " query "
    assert_equal "query", sql.query
  end

  test "add sql date without force_timezone" do
    sql = GitHub::Data::SQL.new ":now", :now => Time.now.utc
    parsed = Time.parse(sql.query[1..-2]) # leave out leading and ending single quotes
    now = Time.now
    assert_in_delta now.to_i, parsed.to_i, 3, "#{now.inspect} expected, #{parsed.inspect} actual"
  end

  test "add sql date with force_timezone" do
    sql = GitHub::Data::SQL.new ":now", :now => Time.now.utc, :force_timezone => :utc
    parsed = Time.parse(sql.query[1..-2]) # leave out leading and ending single quotes

    # Time.parse assumes local time
    # so this creates a local time using the properties from the current time in UTC
    utc = Time.now.utc
    utc_now = Time.local(utc.year, utc.month, utc.day, utc.hour, utc.min, utc.sec)
    assert_in_delta utc_now.to_i, parsed.to_i, 3, "#{utc_now.inspect} expected, #{parsed.inspect} actual"
  end

  test "set some bind params" do
    sql = GitHub::Data::SQL.new
    sql.bind(:first => "firstval").bind(:second => "secondval")

    assert_equal "firstval", sql.binds[:first]
    assert_equal "secondval", sql.binds[:second]
  end

  test "provide a custom connection" do
    sql = GitHub::Data::SQL.new :connection => "stub"

    assert_equal "stub", sql.connection
    assert_nil sql.binds[:connection]
  end

  test "uses the AR query cache when SELECTing" do
    first, second = nil

    ActiveRecord::Base.cache do
      first = GitHub::Data::SQL.new("SELECT RAND()").value
      second = GitHub::Data::SQL.new("SELECT RAND()").value
    end

    assert_in_delta first, second
  end

  test "add_unless_empty adds to a non-empty query" do
    sql = GitHub::Data::SQL.new "non-empty"
    sql.add_unless_empty "foo"

    assert_includes sql.query, "foo"
  end

  test "add_unless_empty does not add to an empty query" do
    sql = GitHub::Data::SQL.new
    sql.add_unless_empty "foo"

    refute_includes sql.query, "foo"
  end

  test "LITERAL returns a Literal" do
    assert_kind_of GitHub::Data::SQL::Literal, GitHub::Data::SQL::LITERAL("foo")
  end

  test "ROWS returns a GitHub::Data::SQL::Rows instance" do
    assert_kind_of GitHub::Data::SQL::Rows, GitHub::Data::SQL::ROWS([[1, 2, 3], [4, 5, 6]])
  end

  test "ROWS raises if non-arrays are provided" do
    assert_raises(ArgumentError) do
      GitHub::Data::SQL::ROWS([1, 2, 3])
    end
  end

  test "affected_rows returns the affected row count" do
    GitHub::Data::SQL.run("CREATE TEMPORARY TABLE affected_rows_test (x INT)")
    GitHub::Data::SQL.run("INSERT INTO affected_rows_test VALUES (1), (2), (3), (4)")
    sql = GitHub::Data::SQL.new("UPDATE affected_rows_test SET x = x + 1")
    sql.run

    assert_equal 4, sql.affected_rows
    GitHub::Data::SQL.run("DROP TABLE affected_rows_test")
  end

  test "affected_rows returns the affected row count even when the query generates warnings" do
    GitHub::Data::SQL.run("CREATE TEMPORARY TABLE affected_rows_test (x INT)")
    GitHub::Data::SQL.run("INSERT INTO affected_rows_test VALUES (1), (2), (3), (4)")
    sql = GitHub::Data::SQL.new("UPDATE affected_rows_test SET x = x + 1 WHERE 1 = '1x'")
    sql.run

    assert_equal 4, sql.affected_rows
    GitHub::Data::SQL.run("DROP TABLE affected_rows_test")
  end
end
