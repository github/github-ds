require File.expand_path("../example_setup", __FILE__)
require "pp"
require "pathname"
root_path = Pathname(__FILE__).dirname.join("..").expand_path
lib_path  = root_path.join("lib")
$:.unshift(lib_path)

require "active_record"

ActiveRecord::Base.establish_connection({
  adapter: "mysql2",
  database: "github_kv_test",
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
