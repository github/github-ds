require File.expand_path("../example_setup", __FILE__)
require "github/sql"

insert_statement = "INSERT INTO example_key_values (`key`, `value`) VALUES (:key, :value)"
select_statement = "SELECT value FROM example_key_values WHERE `key` = :key"
update_statement = "UPDATE example_key_values SET value = :value WHERE `key` = :key"
delete_statement = "DELETE FROM example_key_values WHERE `key` = :key"

################################# Class Style ##################################
sql = GitHub::SQL.run insert_statement, key: "foo", value: "bar"
p sql.last_insert_id
# 1

p GitHub::SQL.value select_statement, key: "foo"
# "bar"

sql = GitHub::SQL.run update_statement, key: "foo", value: "new value"
p sql.affected_rows
# 1

sql = GitHub::SQL.run delete_statement, key: "foo"
p sql.affected_rows
# 1


################################ Instance Style ################################
sql = GitHub::SQL.new insert_statement, key: "foo", value: "bar"
sql.run
p sql.last_insert_id
# 2

sql = GitHub::SQL.new select_statement, key: "foo"
p sql.value
# "bar"

sql = GitHub::SQL.new update_statement, key: "foo", value: "new value"
sql.run
p sql.affected_rows
# 1

sql = GitHub::SQL.new delete_statement, key: "foo"
sql.run
p sql.affected_rows
# 1
