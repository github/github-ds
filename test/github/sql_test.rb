require "test_helper"

class GitHub::SQLTest < Minitest::Test
  local_time = Time.utc(1970, 1, 1, 0, 0, 0)

  Timecop.freeze(local_time) do
    foo = GitHub::SQL::LITERAL "foo"
    rows = GitHub::SQL::ROWS [[1, 2], [3, 4]]
    SANITIZE_TESTS = [
      [GitHub::SQL,          "'GitHub::SQL'"],
      [DateTime.now.utc,     "'1970-01-01 00:00:00'"],
      [Time.now.utc,         "'1970-01-01 00:00:00'"],
      [Time.now.utc.to_date, "'1970-01-01'"],
      [true,                 "TRUE"],
      [false,                "FALSE"],
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
      assert_equal expected, GitHub::SQL.new.sanitize(input),
        "#{input.inspect} sanitizes as #{expected.inspect}"
    end
  end

  def test_sanitize_bad_values
    BAD_VALUE_TESTS.each do |input|
      assert_raises GitHub::SQL::BadValue, "#{input.inspect} (#{input.class}) raises BadValue when sanitized" do
        GitHub::SQL.new.sanitize input
      end
    end
  end

  def test_initialize_with_query
    str = "query"
    sql = GitHub::SQL.new str

    assert_equal Hash.new, sql.binds
    assert_equal str, sql.query
    refute_same sql.query, str
  end

  def test_initialize_with_binds
    binds = { :key => "value" }
    sql = GitHub::SQL.new binds

    assert_equal "", sql.query
    assert_equal "value", sql.binds[:key]
    refute_same sql.binds, binds
  end

  def test_initialize_with_query_and_binds
    sql = GitHub::SQL.new "query :key", :key => "value"

    assert_equal "query 'value'", sql.query
    assert_equal "value", sql.binds[:key]
  end

  def test_initialize_with_single_character_binds
    sql = GitHub::SQL.new "query :x", :x => "y"
    assert_equal "query 'y'", sql.query
    assert_equal "y", sql.binds[:x]
  end

  def test_add
    sql = GitHub::SQL.new

    sql.add("first").add "second"
    assert_equal "first second", sql.query
  end

  def test_add_with_binds
    sql = GitHub::SQL.new

    sql.add ":local", :local => "value"
    assert_equal "'value'", sql.query

    assert_raises GitHub::SQL::BadBind do
      sql.add ":local" # the previous value doesn't persist
    end
  end

  def test_add_with_leading_and_trailing_whitespace
    sql = GitHub::SQL.new " query "
    assert_equal "query", sql.query
  end

  def test_add_date
    now = Time.now.utc
    sql = GitHub::SQL.new ":now", :now => now
    assert_equal "'#{now.to_formatted_s(:db)}'", sql.query
  end

  def test_bind
    sql = GitHub::SQL.new
    sql.bind(:first => "firstval").bind(:second => "secondval")

    assert_equal "firstval", sql.binds[:first]
    assert_equal "secondval", sql.binds[:second]
  end

  def test_initialize_with_connection
    sql = GitHub::SQL.new :connection => "stub"

    assert_equal "stub", sql.connection
    assert_nil sql.binds[:connection]
  end

  def test_uses_ar_query_cache_when_selecting
    events = []
    callback = lambda { |*args| events << ActiveSupport::Notifications::Event.new(*args) }

    ActiveSupport::Notifications.subscribed(callback, "sql.active_record") do
      ActiveRecord::Base.cache do
        GitHub::SQL.new("SELECT RAND()").value
        GitHub::SQL.new("SELECT RAND()").value
      end
    end

    queries = events.reject { |event|
      event.payload[:name] == "CACHE" || event.payload[:cached] == true
    }
    count = queries.size
    assert_equal 1, count,
      "Expected only 1 non-CACHE query from these: #{events.inspect}"
  end

  def test_add_unless_empty_adds_to_a_non_empty_query
    sql = GitHub::SQL.new "non-empty"
    sql.add_unless_empty "foo"

    assert_includes sql.query, "foo"
  end

  def test_add_unless_empty_does_not_add_to_an_empty_query
    sql = GitHub::SQL.new
    sql.add_unless_empty "foo"

    refute_includes sql.query, "foo"
  end

  def test_class_transaction
    GitHub::SQL.run("CREATE TEMPORARY TABLE affected_rows_test (x INT)")

    begin
      GitHub::SQL.transaction do
        GitHub::SQL.run("INSERT INTO affected_rows_test VALUES (1), (2)")
        GitHub::SQL.run("INSERT INTO affected_rows_test VALUES (3), (4)")
        raise "BOOM"
      end
    rescue
      assert_equal 0, GitHub::SQL.new("Select count(*) from affected_rows_test").value
    else
      fail
    end

    GitHub::SQL.transaction do
      GitHub::SQL.run("INSERT INTO affected_rows_test VALUES (1), (2)")
      GitHub::SQL.run("INSERT INTO affected_rows_test VALUES (3), (4)")
    end
    assert_equal 4, GitHub::SQL.new("Select count(*) from affected_rows_test").value
  ensure
    GitHub::SQL.run("DROP TABLE affected_rows_test")
  end

  def test_class_transaction_works_with_options
    GitHub::SQL.run("CREATE TEMPORARY TABLE affected_rows_test (x INT)")

    begin
      GitHub::SQL.transaction(requires_new: true) do
        GitHub::SQL.run("INSERT INTO affected_rows_test VALUES (1), (2)")
        GitHub::SQL.run("INSERT INTO affected_rows_test VALUES (3), (4)")
        raise "BOOM"
      end
    rescue
      assert_equal 0, GitHub::SQL.new("Select count(*) from affected_rows_test").value
    else
      fail
    end
  ensure
    GitHub::SQL.run("DROP TABLE affected_rows_test")
  end

  def test_transaction
    GitHub::SQL.run("CREATE TEMPORARY TABLE affected_rows_test (x INT)")

    begin
      sql = GitHub::SQL.new
      sql.transaction do
        GitHub::SQL.run("INSERT INTO affected_rows_test VALUES (1), (2)")
        GitHub::SQL.run("INSERT INTO affected_rows_test VALUES (3), (4)")
        raise "BOOM"
      end
    rescue
      assert_equal 0, GitHub::SQL.new("Select count(*) from affected_rows_test").value
    else
      fail
    end

    sql = GitHub::SQL.new
    sql.transaction do
      GitHub::SQL.run("INSERT INTO affected_rows_test VALUES (1), (2)")
      GitHub::SQL.run("INSERT INTO affected_rows_test VALUES (3), (4)")
    end
    assert_equal 4, GitHub::SQL.new("Select count(*) from affected_rows_test").value
  ensure
    GitHub::SQL.run("DROP TABLE affected_rows_test")
  end

  def test_transaction_works_with_options
    GitHub::SQL.run("CREATE TEMPORARY TABLE affected_rows_test (x INT)")

    begin
      sql = GitHub::SQL.new
      sql.transaction(requires_new: true) do
        GitHub::SQL.run("INSERT INTO affected_rows_test VALUES (1), (2)")
        GitHub::SQL.run("INSERT INTO affected_rows_test VALUES (3), (4)")
        raise "BOOM"
      end
    rescue
      assert_equal 0, GitHub::SQL.new("Select count(*) from affected_rows_test").value
    else
      fail
    end
  ensure
    GitHub::SQL.run("DROP TABLE affected_rows_test")
  end

  def test_literal
    assert_kind_of GitHub::SQL::Literal, GitHub::SQL::LITERAL("foo")
  end

  def test_rows
    assert_kind_of GitHub::SQL::Rows, GitHub::SQL::ROWS([[1, 2, 3], [4, 5, 6]])
  end

  def test_rows_raises_if_non_arrays_are_provided
    assert_raises(ArgumentError) do
      GitHub::SQL::ROWS([1, 2, 3])
    end
  end

  def test_affected_rows
    begin
      GitHub::SQL.run("CREATE TEMPORARY TABLE affected_rows_test (x INT)")
      GitHub::SQL.run("INSERT INTO affected_rows_test VALUES (1), (2), (3), (4)")

      sql = GitHub::SQL.new("UPDATE affected_rows_test SET x = x + 1")
      sql.run

      assert_equal 4, sql.affected_rows
    ensure
      GitHub::SQL.run("DROP TABLE affected_rows_test")
    end
  end

  def test_affected_rows_even_when_query_generates_warning
    begin
      GitHub::SQL.run("CREATE TEMPORARY TABLE affected_rows_test (x INT)")
      GitHub::SQL.run("INSERT INTO affected_rows_test VALUES (1), (2), (3), (4)")

      sql = GitHub::SQL.run("UPDATE IGNORE affected_rows_test SET x = x + 1 WHERE 1 = '1x'")
      assert_equal 4, sql.affected_rows
      assert_equal 1, sql.connection.raw_connection.warning_count
    ensure
      GitHub::SQL.run("DROP TABLE affected_rows_test")
    end
  end

  def test_add_doesnt_modify_timezone_if_early_return_invoked
    begin
      original_default_timezone = get_default_timezone
      refute_nil original_default_timezone

      ActiveRecord::Base.connection.execute("DROP TABLE IF EXISTS `repositories`")
      ActiveRecord::Base.connection.execute <<-SQL
        CREATE TABLE `repositories` (
          `id` int(11) NOT NULL AUTO_INCREMENT,
          `name` varchar(255) DEFAULT NULL,
          PRIMARY KEY (`id`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8;
      SQL

      sql = GitHub::SQL.new("SELECT * FROM repositories WHERE id = ?", force_timezone: :local)
      sql.add nil, id: 1

      assert_equal original_default_timezone, get_default_timezone
    ensure
      set_default_timezone = original_default_timezone
      ActiveRecord::Base.connection.execute("DROP TABLE IF EXISTS `repositories`")
    end
  end

  def test_results_doesnt_modify_timezone_if_early_return_invoked
    begin
      original_default_timezone = get_default_timezone
      refute_nil original_default_timezone

      ActiveRecord::Base.connection.execute("DROP TABLE IF EXISTS `repositories`")
      ActiveRecord::Base.connection.execute <<-SQL
        CREATE TABLE `repositories` (
          `id` int(11) NOT NULL AUTO_INCREMENT,
          `name` varchar(255) DEFAULT NULL,
          PRIMARY KEY (`id`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8;
      SQL

      sql = GitHub::SQL.new("SELECT * FROM repositories LIMIT 1", force_timezone: :local)
      sql.results
      sql.results

      assert_equal original_default_timezone, get_default_timezone
    ensure
      set_default_timezone original_default_timezone
      ActiveRecord::Base.connection.execute("DROP TABLE IF EXISTS `repositories`")
    end
  end

  def get_default_timezone
    if ActiveRecord.respond_to?(:default_timezone)
      ActiveRecord
    else
      ActiveRecord::Base
    end.default_timezone
  end

  def set_default_timezone(value)
    if ActiveRecord.respond_to?(:default_timezone)
      ActiveRecord
    else
      ActiveRecord::Base
    end.default_timezone = (value)
  end
end

class GitHub::SQLModelTest < Minitest::Test
  class Repository < ActiveRecord::Base; end

  def test_models
    begin
      ActiveRecord::Base.connection.execute("DROP TABLE IF EXISTS `repositories`")
      ActiveRecord::Base.connection.execute <<-SQL
        CREATE TABLE `repositories` (
          `id` int(11) NOT NULL AUTO_INCREMENT,
          `name` varchar(255) DEFAULT NULL,
          `updated_at` datetime DEFAULT NULL,
          `created_at` datetime DEFAULT NULL,
          PRIMARY KEY (`id`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8;
      SQL
      Repository.create

      repository = GitHub::SQL.new(<<-SQL).models(Repository).first
        SELECT `repositories`.* FROM `repositories`
      SQL

      assert_kind_of Repository, repository
    ensure
      ActiveRecord::Base.connection.execute("DROP TABLE IF EXISTS `repositories`")
    end
  end

  def test_results_return_all_values_and_hash_returns_deduplicated_values
    begin
      ActiveRecord::Base.connection.execute("DROP TABLE IF EXISTS `repositories`")
      ActiveRecord::Base.connection.execute <<-SQL
        CREATE TABLE `repositories` (
          `id` int(11) NOT NULL AUTO_INCREMENT,
          `name` varchar(255) DEFAULT NULL,
          `updated_at` datetime DEFAULT NULL,
          `created_at` datetime DEFAULT NULL,
          PRIMARY KEY (`id`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8;
      SQL
      Repository.create(name: "I am a repo")

      sql = GitHub::SQL.new(repo_id: 1)

      sql.add("SELECT id, NULL, NULL, name from repositories")

      assert_equal [1, nil, nil, "I am a repo"], sql.results.flatten

      # Hashes can't have more than one key with the same name, so `to_ary` will de-dup the NULL column values
      assert_equal [{ "id" => 1, "NULL" => nil, "name" => "I am a repo" }], sql.hash_results
    ensure
      ActiveRecord::Base.connection.execute("DROP TABLE IF EXISTS `repositories`")
    end
  end
end
