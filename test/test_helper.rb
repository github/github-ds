require "bundler/setup"
require "pathname"
root_path = Pathname(File.expand_path("../..", __FILE__))
$LOAD_PATH.unshift root_path.join("lib").to_s
require "github/kv"

require "timecop"
require "minitest/autorun"
require "mocha/mini_test"

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
  ActiveRecord::Base.connection.execute("CREATE DATABASE `github_ds_test`")
  attempts += 1
  retry
end
