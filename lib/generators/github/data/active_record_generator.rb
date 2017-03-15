require 'rails/generators/active_record'

module GitHub
  module Data
    module Generators
      class ActiveRecordGenerator < ::Rails::Generators::Base
        include ::Rails::Generators::Migration
        desc "Generates migration for KV table"

        source_paths << File.join(File.dirname(__FILE__), 'templates')

        def create_migration_file
          migration_template "migration.rb", "db/migrate/create_key_values_table.rb"
        end

        def self.next_migration_number(dirname)
          ::ActiveRecord::Generators::Base.next_migration_number(dirname)
        end
      end
    end
  end
end
