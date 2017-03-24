require File.expand_path("../example_setup", __FILE__)
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
    database: "github_ds_test",
  })
  ActiveRecord::Base.connection.execute("DROP TABLE IF EXISTS `key_values`")
  require "generators/github/ds/templates/migration"
  ActiveRecord::Migration.verbose = false
  CreateKeyValuesTable.up
rescue ActiveRecord::NoDatabaseError
  raise if attempts >= 1
  ActiveRecord::Base.establish_connection({
    adapter: "mysql2",
  })
  ActiveRecord::Base.connection.execute("CREATE DATABASE `github_ds_test`")
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
