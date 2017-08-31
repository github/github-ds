require "pp"
require "pathname"
root_path = Pathname(__FILE__).dirname.join("..").expand_path
lib_path  = root_path.join("lib")
$:.unshift(lib_path)

require "active_record"

attempts = 0
begin
  ActiveRecord::Base.establish_connection({
    adapter: "mysql2",
    username: "root",
    database: "github_ds_test",
  })
  ActiveRecord::Base.connection.execute("DROP TABLE IF EXISTS `key_values`")

  # remove db tree if present so we can start fresh
  db_path = root_path.join("db")
  db_path.rmtree if db_path.exist?

  # use generator to create the migration
  require "rails/generators"
  require "generators/github/ds/active_record_generator"
  Rails::Generators.invoke "github:ds:active_record"

  # require migration and run it so we have the key values table
  require db_path.join("migrate").children.first.to_s
  ActiveRecord::Migration.verbose = false
  CreateKeyValuesTable.up
rescue
  raise if attempts >= 1
  ActiveRecord::Base.establish_connection({
    adapter: "mysql2",
    username: "root",
  })
  ActiveRecord::Base.connection.execute("CREATE DATABASE IF NOT EXISTS `github_ds_test`")
  attempts += 1
  retry
end

ActiveRecord::Base.connection.execute("DROP TABLE IF EXISTS `example_key_values`")
ActiveRecord::Base.connection.execute(<<-SQL)
  CREATE TABLE `example_key_values` (
    `id` bigint(20) NOT NULL AUTO_INCREMENT,
    `key` varchar(255) NOT NULL,
    `value` blob NOT NULL,
    PRIMARY KEY (`id`),
    UNIQUE KEY `index_key_values_on_key` (`key`)
  ) ENGINE=InnoDB DEFAULT CHARSET=utf8
SQL
