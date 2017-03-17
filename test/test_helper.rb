require "bundler/setup"
$LOAD_PATH.unshift File.expand_path("../../lib", __FILE__)
require "github/kv"

require "timecop"
require "minitest/autorun"
require "mocha/mini_test"

ActiveRecord::Base.establish_connection({
  adapter: "mysql2",
  database: "github_data_test",
})

ActiveRecord::Base.connection.execute("DROP TABLE IF EXISTS `key_values`")
require "generators/github/store/templates/migration"
ActiveRecord::Migration.verbose = false
CreateKeyValuesTable.up
