# GitHub::DS

`GitHub::DS` is a collection of Ruby libraries for working with SQL on top of ActiveRecord's connection.

* `GitHub::KV` is a key/value data store backed by MySQL.
* `GitHub::SQL` is for building and executing a SQL query. This class uses ActiveRecord's connection class, but provides a better API for bind values and raw data access.
* `GitHub::Result` makes it easier to bake in resiliency through the use of a Result object instead of raising exceptions.

**Current Status**: Used in production extensively at GitHub. Because of this, all changes will be thoroughly vetted, which could slow down the process of contributing. We will do our best to actively communicate status of pull requests with any contributors. If you have any substantial changes that you would like to make, it would be great to first [open an issue](http://github.com/github/github-ds/issues/new) to discuss them with us.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'github-ds'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install github-ds

## Usage

Below is a taste of what you can do with these libraries. If you want to see more, check out the [examples directory](./examples/).

### GitHub::KV

First, you'll need to create the `key_values` table using the included Rails migration generator.

```
rails generate github:ds:active_record
rails db:migrate
```

If you need to change the name of the table used for storing the key-values, you can configure your table name as such, before running the migration:

```
GitHub::KV.configure do |config|
  config.table_name = "new_key_values_table"
end
```

Once you have created and executed the migration, KV can do neat things like this:

```ruby
require "pp"

# Create new instance using ActiveRecord's default connection.
kv = GitHub::KV.new { ActiveRecord::Base.connection }

# Get a key.
pp kv.get("foo")
#<GitHub::Result:0x3fd88cd3ea9c value: nil>

# Set a key.
kv.set("foo", "bar")
# nil

# Get the key again.
pp kv.get("foo")
#<GitHub::Result:0x3fe810d06e4c value: "bar">

# Get multiple keys at once.
pp kv.mget(["foo", "bar"])
#<GitHub::Result:0x3fccccd1b57c value: ["bar", nil]>

# Check for existence of a key.
pp kv.exists("foo")
#<GitHub::Result:0x3fd4ae55ce8c value: true>

# Check for existence of key that does not exist.
pp kv.exists("bar")
#<GitHub::Result:0x3fd4ae55c554 value: false>

# Check for existence of multiple keys at once.
pp kv.mexists(["foo", "bar"])
#<GitHub::Result:0x3ff1e98e18e8 value: [true, false]>

# Set a key's value if the key does not already exist.
pp kv.setnx("foo", "bar")
# false

# Delete a key.
pp kv.del("bar")
# nil

# Delete multiple keys at once.
pp kv.mdel(["foo", "bar"])
# nil
```

Note that due to MySQL's default collation, KV keys are case-insensitive.

### GitHub::SQL

```ruby
# Select, insert, update, delete or whatever you need...
GitHub::SQL.results <<-SQL
  SELECT * FROM example_key_values
SQL

GitHub::SQL.run <<-SQL, key: "foo", value: "bar"
  INSERT INTO example_key_values (`key`, `value`)
  VALUES (:key, :value)
SQL

GitHub::SQL.value <<-SQL, key: "foo"
  SELECT value FROM example_key_values WHERE `key` = :key
SQL

# Or slowly build up a query based on conditionals...
sql = GitHub::SQL.new <<-SQL
  SELECT `value` FROM example_key_values
SQL

key = ENV["KEY"]
unless key.nil?
  sql.add <<-SQL, key: key
    WHERE `key` = :key
  SQL
end

limit = ENV["LIMIT"]
unless limit.nil?
  sql.add <<-SQL, limit: limit.to_i
    ORDER BY `key` ASC
    LIMIT :limit
  SQL
end

p sql.results
```

### GitHub::Result

```ruby
def do_something
  1
end

def do_something_that_errors
  raise "noooooppppeeeee"
end

result = GitHub::Result.new { do_something }
p result.ok? # => true
p result.value! # => 1

result = GitHub::Result.new { do_something_that_errors }
p result.ok? # => false
p result.value { "default when error happens" } # => "default when error happens"
begin
  result.value! # raises exception because error happened
rescue => error
  p result.error
  p error
end

# Outputs Step 1, 2, 3
result = GitHub::Result.new {
  GitHub::Result.new { puts "Step 1: success!" }
}.then { |value|
  GitHub::Result.new { puts "Step 2: success!" }
}.then { |value|
  GitHub::Result.new { puts "Step 3: success!" }
}
p result.ok? # => true

# Outputs Step 1, 2 and stops.
result = GitHub::Result.new {
  GitHub::Result.new { puts "Step 1: success!" }
}.then { |value|
  GitHub::Result.new {
    puts "Step 2: failed!"
    raise
  }
}.then { |value|
  GitHub::Result.new {
    puts "Step 3: should not get here because previous step failed!"
  }
}
p result.ok? # => false
```

## Caveats

### GitHub::KV Expiration

KV supports expiring keys and obeys expiration when performing operations, but does not actually purge expired rows. At GitHub, we use [pt-archiver](https://www.percona.com/doc/percona-toolkit/2.1/pt-archiver.html) to nibble expired rows. We configure it to do a replica lag check and use the following options:

* **index_name**: `"index_key_values_on_expires_at"`
* **limit**: `1000`
* **where**: `"expires_at <= NOW()"`

## Development

After checking out the repo, run `script/bootstrap` to install dependencies. Then, run `script/test` to run the tests. You can also run `script/console` for an interactive prompt that will allow you to experiment.

**Note**: You will need a MySQL database with no password set for the root user for the tests. Running `docker-compose up` will boot just that. This functionality is not currently used by GitHub and was from a contributor, so please let us know if it does not work or gets out of date (pull request is best, but an issue will do).

To install this gem onto your local machine, run `script/install`. To release a new version, update the version number in `version.rb`, commit, and then run `script/release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/github/github-ds. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [Contributor Covenant](http://contributor-covenant.org) code of conduct. We recommend reading the [contributing guide](./CONTRIBUTING.md) as well.

## Roadmap

Nothing currently on our radar other than continued maintenance. Have a big idea? [Let us know](http://github.com/github/github-ds/issues/new).

## Maintainers

| pic | @mention |
|---|---|
| ![@haileysome](https://avatars3.githubusercontent.com/u/179065?s=64) | [@haileysome](https://github.com/haileysome) |
| ![@jnunemaker](https://avatars3.githubusercontent.com/u/235?s=64) | [@jnunemaker](https://github.com/jnunemaker) |
| ![@miguelff](https://avatars3.githubusercontent.com/u/210307?s=64) | [@miguelff](https://github.com/miguelff) |
| ![@zerowidth](https://avatars3.githubusercontent.com/u/3999?s=64) | [@zerowidth](https://github.com/zerowidth) |

## License

The gem is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).
