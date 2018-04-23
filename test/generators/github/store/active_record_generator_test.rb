require "test_helper"
require "rails"
require "rails/test_help"
require "active_record"
require "rails/generators/test_case"
require "generators/github/ds/active_record_generator"
require "mysql2"

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
    assert_migration "db/migrate/create_key_values_table.rb", <<-EOM
class CreateKeyValuesTable < ActiveRecord::Migration#{migration_version}
  def self.up
    create_table :key_values do |t|
      t.string :key, :null => false
      t.binary :value, :null => false
      t.datetime :expires_at, :null => true
      t.timestamps :null => false
    end

    add_index :key_values, :key, :unique => true
    add_index :key_values, :expires_at

    change_column :key_values, :id, "bigint(20) NOT NULL AUTO_INCREMENT"
  end

  def self.down
    drop_table :key_values
  end
end
EOM
  end
end
