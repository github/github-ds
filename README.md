# Github::Data

GitHub::Data is a few handy classes on top of ActiveRecord for working with SQL.

* `GitHub::Data::KV` is a key/value data store backed by MySQL, built on top of `SQL` and `Result`.
* `GitHub::Data::SQL` is for building and executing a SQL query. This class uses ActiveRecord's connection class, but provides a better API for bind values and raw data access.
* `GitHub::Data::Result` makes it easier to bake in resiliency through the use of a Result object instead of raising exceptions.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'github-data'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install github-data

## Usage

### GitHub::Data::KV

First, you'll need to create the key_values table using the included Rails migration generator.

```
rails generate github:data:active_record
rails db:migrate
```

Once you have the table, KV can do neat things like this:

```ruby
require "pp"
require "github/data/kv"

# Create new instance using ActiveRecord's default connection.
kv = GitHub::Data::KV.new { ActiveRecord::Base.connection }

# Get a key.
pp kv.get("foo")
#<GitHub::Data::Result:0x3fd88cd3ea9c value: nil>

# Set a key.
kv.set("foo", "bar")
# nil

# Get the key again.
pp kv.get("foo")
#<GitHub::Data::Result:0x3fe810d06e4c value: "bar">

# Get multiple keys at once.
pp kv.mget(["foo", "bar"])
#<GitHub::Data::Result:0x3fccccd1b57c value: ["bar", nil]>

# Check for existence of a key.
pp kv.exists("foo")
#<GitHub::Data::Result:0x3fd4ae55ce8c value: true>

# Check for existence of key that does not exist.
pp kv.exists("bar")
#<GitHub::Data::Result:0x3fd4ae55c554 value: false>

# Check for existence of multiple keys at once.
pp kv.mexists(["foo", "bar"])
#<GitHub::Data::Result:0x3ff1e98e18e8 value: [true, false]>

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

## Development

After checking out the repo, run `script/setup` to install dependencies. Then, run `rake test` to run the tests. You can also run `script/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/github/github-data. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [Contributor Covenant](http://contributor-covenant.org) code of conduct.


## License

The gem is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).
