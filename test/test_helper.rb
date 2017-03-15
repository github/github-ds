require "bundler/setup"
$LOAD_PATH.unshift File.expand_path("../../lib", __FILE__)
require "github/data"

require "timecop"
require "minitest/autorun"
require "mocha/mini_test"

ActiveRecord::Migration.verbose = false
ActiveRecord::Base.establish_connection({
  adapter: "mysql2",
  database: "github_data_test",
})

ActiveRecord::Base.connection.execute("DROP TABLE IF EXISTS `key_values`")
ActiveRecord::Base.connection.execute(<<-EOS)
  CREATE TABLE `key_values` (
    `id` bigint(20) NOT NULL AUTO_INCREMENT,
    `key` varchar(255) NOT NULL,
    `value` blob NOT NULL,
    `created_at` datetime NOT NULL,
    `updated_at` datetime NOT NULL,
    `expires_at` datetime DEFAULT NULL,
    PRIMARY KEY (`id`),
    UNIQUE KEY `index_key_values_on_key` (`key`),
    KEY `index_key_values_on_expires_at` (`expires_at`)
  ) ENGINE=InnoDB DEFAULT CHARSET=utf8
EOS
