require File.expand_path("../example_setup", __FILE__)
require "github/sql"

class SomeModel < ActiveRecord::Base
  self.abstract_class = true

  establish_connection({
    adapter: "mysql2",
    database: "github_store_test",
  })
end

insert_statement = "INSERT INTO example_key_values (`key`, `value`) VALUES (:key, :value)"

ActiveRecord::Base.transaction do
  # Insert bar on base connection.
  GitHub::SQL.run insert_statement, key: "bar", value: "baz", connection: ActiveRecord::Base.connection

  SomeModel.transaction do
    # Insert foo on different connection.
    GitHub::SQL.run insert_statement, key: "foo", value: "bar", connection: SomeModel.connection
  end

  # Roll back "bar" insertion.
  raise ActiveRecord::Rollback
end

# Show that "bar" key is not here because that connection's transaction was
# rolled back. SomeModel is a different connection and started a different
# transaction, which succeeded, so "foo" key was created.
p GitHub::SQL.values "SELECT `key` FROM example_key_values"
# ["foo"]
