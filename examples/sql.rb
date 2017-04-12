require File.expand_path("../example_setup", __FILE__)
require "github/sql"

################################# Class Style ##################################
sql = GitHub::SQL.run <<-SQL, key: "foo", value: "bar"
  INSERT INTO example_key_values (`key`, `value`) VALUES (:key, :value)
SQL
p sql.last_insert_id
# 1

p GitHub::SQL.value <<-SQL, key: "foo"
  SELECT value FROM example_key_values WHERE `key` = :key
SQL
# "bar"

sql = GitHub::SQL.run <<-SQL, key: "foo", value: "new value"
  UPDATE example_key_values SET value = :value WHERE `key` = :key
SQL
p sql.affected_rows
# 1

sql = GitHub::SQL.run <<-SQL, key: "foo"
  DELETE FROM example_key_values WHERE `key` = :key
SQL
p sql.affected_rows
# 1


################################ Instance Style ################################
sql = GitHub::SQL.new <<-SQL, key: "foo", value: "bar"
  INSERT INTO example_key_values (`key`, `value`) VALUES (:key, :value)
SQL
sql.run
p sql.last_insert_id
# 2

sql = GitHub::SQL.new <<-SQL, key: "foo"
  SELECT value FROM example_key_values WHERE `key` = :key
SQL
p sql.value
# "bar"

sql = GitHub::SQL.new <<-SQL, key: "foo", value: "new value"
  UPDATE example_key_values SET value = :value WHERE `key` = :key
SQL
sql.run
p sql.affected_rows
# 1

sql = GitHub::SQL.new <<-SQL, key: "foo"
  DELETE FROM example_key_values WHERE `key` = :key
SQL
sql.run
p sql.affected_rows
# 1
