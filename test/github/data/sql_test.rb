require "test_helper"

class GitHub::Data::SQLTest < Minitest::Test
  local_time = Time.utc(1970, 1, 1, 0, 0, 0)

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

  def test_sanitize
    SANITIZE_TESTS.each do |input, expected|
      assert_equal expected, GitHub::Data::SQL.new.sanitize(input),
      "#{input.inspect} sanitizes as #{expected.inspect}"
    end
  end

  def test_sanitize_bad_values
    BAD_VALUE_TESTS.each do |input|
      assert_raises GitHub::Data::SQL::BadValue, "#{input.inspect} (#{input.class}) raises BadValue when sanitized" do
        GitHub::Data::SQL.new.sanitize input
      end
    end
  end

  def test_initialize_with_query
    str = "query"
    sql = GitHub::Data::SQL.new str

    assert_equal Hash.new, sql.binds
    assert_equal str, sql.query
    refute_same sql.query, str
  end

  def test_initialize_with_binds
    binds = { :key => "value" }
    sql = GitHub::Data::SQL.new binds

    assert_equal "", sql.query
    assert_equal "value", sql.binds[:key]
    refute_same sql.binds, binds
  end

  def test_initialize_with_query_and_binds
    sql = GitHub::Data::SQL.new "query :key", :key => "value"

    assert_equal "query 'value'", sql.query
    assert_equal "value", sql.binds[:key]
  end

  def test_initialize_with_single_character_binds
    sql = GitHub::Data::SQL.new "query :x", :x => "y"
    assert_equal "query 'y'", sql.query
    assert_equal "y", sql.binds[:x]
  end

  def test_add
    sql = GitHub::Data::SQL.new

    sql.add("first").add "second"
    assert_equal "first second", sql.query
  end

  def test_add_with_binds
    sql = GitHub::Data::SQL.new

    sql.add ":local", :local => "value"
    assert_equal "'value'", sql.query

    assert_raises GitHub::Data::SQL::BadBind do
      sql.add ":local" # the previous value doesn't persist
    end
  end

  def test_add_with_leading_and_trailing_whitespace
    sql = GitHub::Data::SQL.new " query "
    assert_equal "query", sql.query
  end

  def test_add_date
    now = Time.now.utc
    sql = GitHub::Data::SQL.new ":now", :now => now
    assert_equal "'#{now.to_s(:db)}'", sql.query
  end

  def test_bind
    sql = GitHub::Data::SQL.new
    sql.bind(:first => "firstval").bind(:second => "secondval")

    assert_equal "firstval", sql.binds[:first]
    assert_equal "secondval", sql.binds[:second]
  end

  def test_initialize_with_connection
    sql = GitHub::Data::SQL.new :connection => "stub"

    assert_equal "stub", sql.connection
    assert_nil sql.binds[:connection]
  end

  def test_uses_ar_query_cache_when_selecting
    first, second = nil

    ActiveRecord::Base.cache do
      first = GitHub::Data::SQL.new("SELECT RAND()").value
      second = GitHub::Data::SQL.new("SELECT RAND()").value
    end

    assert_in_delta first, second
  end

  def test_add_unless_empty_adds_to_a_non_empty_query
    sql = GitHub::Data::SQL.new "non-empty"
    sql.add_unless_empty "foo"

    assert_includes sql.query, "foo"
  end

  def test_add_unless_empty_does_not_add_to_an_empty_query
    sql = GitHub::Data::SQL.new
    sql.add_unless_empty "foo"

    refute_includes sql.query, "foo"
  end

  def test_literal
    assert_kind_of GitHub::Data::SQL::Literal, GitHub::Data::SQL::LITERAL("foo")
  end

  def test_rows
    assert_kind_of GitHub::Data::SQL::Rows, GitHub::Data::SQL::ROWS([[1, 2, 3], [4, 5, 6]])
  end

  def test_rows_raises_if_non_arrays_are_provided
    assert_raises(ArgumentError) do
      GitHub::Data::SQL::ROWS([1, 2, 3])
    end
  end

  def test_affected_rows
    begin
      GitHub::Data::SQL.run("CREATE TEMPORARY TABLE affected_rows_test (x INT)")
      GitHub::Data::SQL.run("INSERT INTO affected_rows_test VALUES (1), (2), (3), (4)")

      sql = GitHub::Data::SQL.new("UPDATE affected_rows_test SET x = x + 1")
      sql.run

      assert_equal 4, sql.affected_rows
    ensure
      GitHub::Data::SQL.run("DROP TABLE affected_rows_test")
    end
  end

  def test_affected_rows_even_when_query_generates_warning
    begin
      GitHub::Data::SQL.run("CREATE TEMPORARY TABLE affected_rows_test (x INT)")
      GitHub::Data::SQL.run("INSERT INTO affected_rows_test VALUES (1), (2), (3), (4)")
      sql = GitHub::Data::SQL.new("UPDATE affected_rows_test SET x = x + 1 WHERE 1 = '1x'")
      sql.run

      assert_equal 4, sql.affected_rows
    ensure
      GitHub::Data::SQL.run("DROP TABLE affected_rows_test")
    end
  end
end
