require File.expand_path("../example_setup", __FILE__)
require "github/sql"

class SomeModel < ActiveRecord::Base
  self.abstract_class = true

  establish_connection({
    adapter: "mysql2",
    database: "github_ds_test",
    username: "root",
  })
end

ActiveRecord::Base.transaction do
  # Insert bar on base connection.
  GitHub::SQL.run <<-SQL, key: "bar", value: "baz", connection: ActiveRecord::Base.connection
    INSERT INTO example_key_values (`key`, `value`) VALUES (:key, :value)
  SQL

  SomeModel.transaction do
    # Insert foo on different connection.
    GitHub::SQL.run <<-SQL, key: "foo", value: "bar", connection: SomeModel.connection
      INSERT INTO example_key_values (`key`, `value`) VALUES (:key, :value)
    SQL
  end

  # Roll back "bar" insertion.
  raise ActiveRecord::Rollback
end

# Show that "bar" key is not here because that connection's transaction was
# rolled back. SomeModel is a different connection and started a different
# transaction, which succeeded, so "foo" key was created.
p GitHub::SQL.values <<-SQL
  SELECT `key` FROM example_key_values
SQL
# ["foo"]
