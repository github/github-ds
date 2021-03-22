require "rails/generators/active_record"
require "rails/version"
module Github
  module Ds
    module Generators
      class ActiveRecordGenerator < ::Rails::Generators::Base
        class_option :migration_name, type: :string, default: "CreateKeyValuesTable"
        class_option :table_name, type: :string, default: ::GitHub::KV.config.table_name

        include ::Rails::Generators::Migration
        desc "Generates migration for KV table"

        source_paths << File.join(File.dirname(__FILE__), "templates")

        def create_migration_file
          migration_template "migration.rb", "db/migrate/create_#{table_name}_table.rb", migration_version: migration_version
        end

        def self.next_migration_number(dirname)
          ::ActiveRecord::Generators::Base.next_migration_number(dirname)
        end

        def self.migration_version
          if Rails::VERSION::MAJOR.to_i >= 5
            "[#{Rails::VERSION::MAJOR}.#{Rails::VERSION::MINOR}]"
          end
        end

        def migration_name
          @options["migration_name"]
        end

        def migration_version
          self.class.migration_version
        end


        def table_name
          @options["table_name"]
        end
      end
    end
  end
end
