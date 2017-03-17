# Github::KV

`GitHub::KV` is a key/value data store backed by MySQL and written in Ruby using `GitHub::SQL` and `GitHub::Result`.

`GitHub::SQL` is for building and executing a SQL query. This class uses ActiveRecord's connection class, but provides a better API for bind values and raw data access.

`GitHub::Result` makes it easier to bake in resiliency through the use of a Result object instead of raising exceptions.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'github-store'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install github-store

## Usage

First, you'll need to create the `key_values` table using the included Rails migration generator.

```
rails generate github:kv:active_record
rails db:migrate
```

Once you have created and executed the migration, KV can do neat things like this:

```ruby
require "pp"
require "github/kv"

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

## Caveats

### Expiration

KV supports expiring keys and obeys expiration when performing operations, but does not actually purge expired rows. At GitHub, we use [pt-archiver](https://www.percona.com/doc/percona-toolkit/2.1/pt-archiver.html) to nibble expired rows. We configure it to do a replica lag check and use the following options:

* **index_name**: `"index_key_values_on_expires_at"`
* **limit**: `1000`
* **where**: `"expires_at <= NOW()"`

## Development

After checking out the repo, run `script/setup` to install dependencies. Then, run `rake test` to run the tests. You can also run `script/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/github/github-store. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [Contributor Covenant](http://contributor-covenant.org) code of conduct.


## License

The gem is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).
