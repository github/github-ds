require "bundler/setup"
require "pp"
require "pathname"
root_path = Pathname(File.expand_path("../..", __FILE__))
$LOAD_PATH.unshift root_path.join("lib").to_s
require "github/ds"
require "github/kv"
require "timecop"
require "minitest/autorun"
require "mocha/mini_test"
require "minitest/focus"
require "pry"

ActiveRecord::Base.configurations = {
  "without_database" => {
    "adapter" => "mysql2",
    "username" => "root",
    "host" => "127.0.0.1",
  },
  "with_database" => {
    "adapter" => "mysql2",
    "username" => "root",
    "host" => "127.0.0.1",
    "database" => "github_ds_test",
  },
}

GitHub::KV.reset

attempts = 0
begin
  ActiveRecord::Base.establish_connection :with_database
  ActiveRecord::Base.connection.execute("DROP TABLE IF EXISTS `key_values`")
  ActiveRecord::Base.connection.execute("DROP TABLE IF EXISTS `kv_case_sensitive`")

  # remove db tree if present so we can start fresh
  db_path = root_path.join("db")
  db_path.rmtree if db_path.exist?

  # use generator to create the migration
  require "rails/generators"
  require "generators/github/ds/active_record_generator"
  Rails::Generators.invoke "github:ds:active_record"
  Rails::Generators.invoke "github:ds:active_record", %w(--table-name kv_case_sensitive --migration-name CreateCaseSensitiveKV --case-sensitive)

  # require migration and run it so we have the key values table
  db_path.join("migrate").children.each do |migration|
    require migration
  end
  ActiveRecord::Migration.verbose = false
  CreateKeyValuesTable.up
  CreateCaseSensitiveKV.up
rescue
  raise if attempts >= 1
  ActiveRecord::Base.establish_connection :without_database
  ActiveRecord::Base.connection.execute("CREATE DATABASE IF NOT EXISTS `github_ds_test`")
  attempts += 1
  retry
end
