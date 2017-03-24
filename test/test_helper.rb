require "bundler/setup"
$LOAD_PATH.unshift File.expand_path("../../lib", __FILE__)
require "github/kv"

require "timecop"
require "minitest/autorun"
require "mocha/mini_test"

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
