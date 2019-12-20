require "test_helper"
require "rails"
require "rails/test_help"
require "active_record"
require "rails/generators/test_case"
require "generators/github/ds/active_record_generator"

class GithubDSActiveRecordGeneratorTest < Rails::Generators::TestCase
  tests Github::Ds::Generators::ActiveRecordGenerator
  destination File.expand_path("../../../../tmp", __FILE__)
  setup :prepare_destination

  def test_generates_migration
    run_generator
    migration_version = if Rails::VERSION::MAJOR.to_i < 5
      ""
    else
      "[#{Rails::VERSION::MAJOR}.#{Rails::VERSION::MINOR}]"
    end
    table_name = "key_values"
    assert_migration "db/migrate/create_key_values_table.rb", <<-EOM
class CreateKeyValuesTable < ActiveRecord::Migration#{migration_version}
  def self.up
    create_table :#{table_name} do |t|
      t.string :key, :null => false
      t.binary :value, :null => false
      t.datetime :expires_at, :null => true
      t.timestamps :null => false
    end

    add_index  :#{table_name}, :key, :unique => true
    add_index  :#{table_name}, :expires_at

    change_column  :#{table_name}, :id, "bigint(20) NOT NULL AUTO_INCREMENT"
  end

  def self.down
    drop_table  :#{table_name}
  end
end
EOM
  end
end
