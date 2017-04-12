require File.expand_path("../example_setup", __FILE__)
require "github/sql"

GitHub::SQL.run <<-SQL
  INSERT INTO example_key_values (`key`, `value`)
  VALUES ("foo", "bar"), ("baz", "wick")
SQL

sql = GitHub::SQL.new <<-SQL
  SELECT `VALUE` FROM example_key_values
SQL

key = ENV["KEY"]
unless key.nil?
  sql.add <<-SQL, key: key
    WHERE `key` = :key
  SQL
end

limit = ENV["LIMIT"]
unless limit.nil?
  sql.add <<-SQL, limit: limit.to_i
    ORDER BY `key` ASC
    LIMIT :limit
  SQL
end

p sql.results

# Only select value for key = foo
# $ env KEY=foo bundle exec ruby examples/sql_add.rb
# [["bar"]]
#
# Only select value for key = bar
# $ env KEY=bar bundle exec ruby examples/sql_add.rb
# []
#
# Only select value for key = baz
# $ env KEY=baz bundle exec ruby examples/sql_add.rb
# [["wick"]]
#
# Select all values
# $ bundle exec ruby examples/sql_add.rb
# [["bar"], ["wick"]]
#
# Select only 1 key.
# $ env LIMIT=1 bundle exec ruby examples/sql_add.rb
# [["wick"]]
