require_relative "kv/config"
require_relative "result"
require_relative "sql"

# GitHub::KV is a key/value data store backed by MySQL (however, the backing
# store used should be regarded as an implementation detail).
#
# Usage tips:
#
#   * Components in key names should be ordered by cardinality, from lowest to
#     highest. That is, static key components should be at the front of the key
#     and key components that vary should be at the end of the key in order of
#     how many potential values they might have.
#
#     For example, if using GitHub::KV to store a user preferences, the key
#     should be named "user.#{preference_name}.#{user_id}". Notice that the
#     part of the key that never changes ("user") comes first, followed by
#     the name of the preference (of which there might be a handful), followed
#     finally by the user id (of which there are millions).
#
#     This will make it easier to scan for keys later on, which is a necessity
#     if we ever need to move this data out of GitHub::KV or if we need to
#     search the keyspace for some reason (for example, if it's a preference
#     that we're planning to deprecate, putting the preference name near the
#     beginning of the key name makes it easier to search for all users with
#     that preference set).
#
#   * All reader methods in GitHub::KV return values wrapped inside a Result
#     object.
#
#     If any of these methods raise an exception for some reason (for example,
#     the database is down), they will return a Result value representing this
#     error rather than raising the exception directly. See lib/github/result.rb
#     for more documentation on GitHub::Result including usage examples.
#
#     When using GitHub::KV, it's important to handle error conditions and not
#     assume that GitHub::Result objects will always represent success.
#     Code using GitHub::KV should be able to fail partially if
#     GitHub::KV is down. How exactly to do this will depend on a
#     case-by-case basis - it may involve falling back to a default value, or it
#     might involve showing an error message to the user while still letting the
#     rest of the page load.
#
module GitHub
  class KV
    MAX_KEY_LENGTH = 255
    MAX_VALUE_LENGTH = 65535

    KeyLengthError = Class.new(StandardError)
    ValueLengthError = Class.new(StandardError)
    UnavailableError = Class.new(StandardError)
    InvalidValueError = Class.new(StandardError)

    class MissingConnectionError < StandardError; end

    attr_accessor :use_local_time
    attr_writer :config

    def self.config
      @config ||= Config.new
    end

    def self.reset
      @config = Config.new
    end

    def self.configure
      yield(config)
    end

    # initialize :: [Exception], Boolean, Proc -> nil
    #
    # Initialize a new KV instance.
    #
    # encapsulated_errors - An Array of Exception subclasses that, when raised,
    #                       will be replaced with UnavailableError.
    # use_local_time:     - Whether to use Ruby's `Time.now` instaed of MySQL's
    #                       `NOW()` function. This is mostly useful in testing
    #                       where time needs to be modified (eg. Timecop).
    #                       Default false.
    # &conn_block         - A block to call to open a new database connection.
    #
    # Returns nothing.
    def initialize(config: GitHub::KV.config, &conn_block)
      @encapsulated_errors = config.encapsulated_errors
      @use_local_time = config.use_local_time
      @table_name = config.table_name
      @conn_block = conn_block
    end

    def connection
      @conn_block.try(:call) || (raise MissingConnectionError, "KV must be initialized with a block that returns a connection")
    end

    # get :: String -> Result<String | nil>
    #
    # Gets the value of the specified key.
    #
    # Example:
    #
    #   kv.get("foo")
    #     # => #<Result value: "bar">
    #
    #   kv.get("octocat")
    #     # => #<Result value: nil>
    #
    def get(key)
      validate_key(key)

      mget([key]).map { |values| values[0] }
    end

    # mget :: [String] -> Result<[String | nil]>
    #
    # Gets the values of all specified keys. Values will be returned in the
    # same order as keys are specified. nil will be returned in place of a
    # String for keys which do not exist.
    #
    # Example:
    #
    #   kv.mget(["foo", "octocat"])
    #     # => #<Result value: ["bar", nil]
    #
    def mget(keys)
      validate_key_array(keys)

      Result.new {
        kvs = GitHub::SQL.results(<<-SQL, :keys => keys, :now => now, :connection => connection).to_h
          SELECT `key`, value FROM #{@table_name} WHERE `key` IN :keys AND (`expires_at` IS NULL OR `expires_at` > :now)
        SQL

        kvs.keys.each { |key| kvs[key.downcase] = kvs[key] }
        keys.map { |key| kvs[key.downcase] }
      }
    end

    # set :: String, String, expires: Time? -> nil
    #
    # Sets the specified key to the specified value. Returns nil. Raises on
    # error.
    #
    # Example:
    #
    #   kv.set("foo", "bar")
    #     # => nil
    #
    def set(key, value, expires: nil)
      validate_key(key)
      validate_value(value)

      mset({ key => value }, expires: expires)
    end

    # mset :: { String => String }, expires: Time? -> nil
    #
    # Sets the specified hash keys to their associated values, setting them to
    # expire at the specified time. Returns nil. Raises on error.
    #
    # Example:
    #
    #   kv.mset({ "foo" => "bar", "baz" => "quux" })
    #     # => nil
    #
    #   kv.mset({ "expires" => "soon" }, expires: 1.hour.from_now)
    #     # => nil
    #
    def mset(kvs, expires: nil)
      validate_key_value_hash(kvs)
      validate_expires(expires) if expires

      rows = kvs.map { |key, value|
        value = value.is_a?(GitHub::SQL::Literal) ? value : GitHub::SQL::BINARY(value)
        [key, value, now, now, expires || GitHub::SQL::NULL]
      }

      encapsulate_error do
        GitHub::SQL.run(<<-SQL, :rows => GitHub::SQL::ROWS(rows), :connection => connection)
          INSERT INTO #{@table_name} (`key`, value, created_at, updated_at, expires_at)
          VALUES :rows
          ON DUPLICATE KEY UPDATE
            value = VALUES(value),
            updated_at = VALUES(updated_at),
            expires_at = VALUES(expires_at)
        SQL
      end

      nil
    end

    # exists :: String -> Result<Boolean>
    #
    # Checks for existence of the specified key.
    #
    # Example:
    #
    #   kv.exists("foo")
    #     # => #<Result value: true>
    #
    #   kv.exists("octocat")
    #     # => #<Result value: false>
    #
    def exists(key)
      validate_key(key)

      mexists([key]).map { |values| values[0] }
    end

    # mexists :: [String] -> Result<[Boolean]>
    #
    # Checks for existence of all specified keys. Booleans will be returned in
    # the same order as keys are specified.
    #
    # Example:
    #
    #   kv.mexists(["foo", "octocat"])
    #     # => #<Result value: [true, false]>
    #
    def mexists(keys)
      validate_key_array(keys)

      Result.new {
        existing_keys = GitHub::SQL.values(<<-SQL, :keys => keys, :now => now, :connection => connection).to_set
          SELECT `key` FROM #{@table_name} WHERE `key` IN :keys AND (`expires_at` IS NULL OR `expires_at` > :now)
        SQL

        keys.map { |key| existing_keys.include?(key) }
      }
    end

    # setnx :: String, String, expires: Time? -> Boolean
    #
    # Sets the specified key to the specified value only if it does not
    # already exist.
    #
    # Returns true if the key was set, false otherwise. Raises on error.
    #
    # Example:
    #
    #   kv.setnx("foo", "bar")
    #     # => false
    #
    #   kv.setnx("octocat", "monalisa")
    #     # => true
    #
    #   kv.setnx("expires", "soon", expires: 1.hour.from_now)
    #     # => true
    #
    def setnx(key, value, expires: nil)
      validate_key(key)
      validate_value(value)
      validate_expires(expires) if expires

      encapsulate_error {
        # if the key already exists but has expired, prune it first. We could
        # achieve the same thing with the right INSERT ... ON DUPLICATE KEY UPDATE
        # query, but then we would not be able to rely on affected_rows

        GitHub::SQL.run(<<-SQL, :key => key, :now => now, :connection => connection)
          DELETE FROM #{@table_name} WHERE `key` = :key AND expires_at <= :now
        SQL

        value = value.is_a?(GitHub::SQL::Literal) ? value : GitHub::SQL::BINARY(value)
        sql = GitHub::SQL.run(<<-SQL, :key => key, :value => value, :now => now, :expires => expires || GitHub::SQL::NULL, :connection => connection)
          INSERT IGNORE INTO #{@table_name} (`key`, value, created_at, updated_at, expires_at)
          VALUES (:key, :value, :now, :now, :expires)
        SQL

        sql.affected_rows > 0
      }
    end

    # increment :: String, Integer, expires: Time? -> Integer
    #
    # Increment the key's value by an amount.
    #
    # key             - The key to increment.
    # amount          - The amount to increment the key's value by.
    #                   The user can increment by both positive and
    #                   negative values
    # expires         - When the key should expire.
    # touch_on_insert - Only when expires is specified. When true
    #                   the expires value is only touched upon
    #                   inserts. Otherwise the record is always
    #                   touched.
    #
    # Returns the key's value after incrementing.
    def increment(key, amount: 1, expires: nil, touch_on_insert: false)
      validate_key(key)
      validate_amount(amount) if amount
      validate_expires(expires) if expires
      validate_touch(touch_on_insert, expires)

      expires ||= GitHub::SQL::NULL

      # This query uses a few MySQL "hacks" to ensure that the incrementing
      # is done atomically and the value is returned. The first trick is done
      # using the `LAST_INSERT_ID` function. This allows us to manually set
      # the LAST_INSERT_ID returned by the query. Here we are able to set it
      # to the new value when an increment takes place, essentially allowing us
      # to do: `UPDATE...;SELECT value from key_value where key=:key` in a
      # single step.
      #
      # However the `LAST_INSERT_ID` trick is only used when the value is
      # updated. Upon a fresh insert we know the amount is going to be set
      # to the amount specified.
      #
      # Lastly we only do these tricks when the value at the key is an integer.
      # If the value is not an integer the update ensures the values remain the
      # same and we raise an error.
      encapsulate_error {
        sql = GitHub::SQL.run(<<-SQL, key: key, amount: amount, now: now, expires: expires, touch: !touch_on_insert, connection: connection)
          INSERT INTO #{@table_name} (`key`, `value`, `created_at`, `updated_at`, `expires_at`)
          VALUES(:key, :amount, :now, :now, :expires)
          ON DUPLICATE KEY UPDATE
            `value`=IF(
              concat('',`value`*1) = `value`,
              LAST_INSERT_ID(IF(
                `expires_at` IS NULL OR `expires_at`>=:now,
                `value`+:amount,
                :amount
              )),
              `value`
            ),
            `updated_at`=IF(
              concat('',`value`*1) = `value`,
              :now,
              `updated_at`
            ),
            `expires_at`=IF(
              concat('',`value`*1) = `value`,
              IF(
                :touch OR (`expires_at` IS NULL OR `expires_at`<:now),
                :expires,
                `expires_at`
              ),
              `expires_at`
            )
        SQL

        # The ordering of these statements is extremely important if we are to
        # support incrementing a negative amount. The checks occur in this order:
        # 1. Check if an update with new values occurred? If so return the result
        #    This could potentially result in `sql.last_insert_id` with a value
        #    of 0, thus it must be before the second check.
        # 2. Check if an update took place but nothing changed (I.E. no new value
        #    was set)
        # 3. Check if an insert took place.
        #
        # See https://dev.mysql.com/doc/refman/8.0/en/insert-on-duplicate.html for
        # more information (NOTE: CLIENT_FOUND_ROWS is set)
        if sql.affected_rows == 2
          # An update took place in which data changed. We use a hack to set
          # the last insert ID to be the new value.
          sql.last_insert_id
        elsif sql.affected_rows == 0 || (sql.affected_rows == 1 && sql.last_insert_id == 0)
          # No insert took place nor did any update occur. This means that
          # the value was not an integer thus not incremented.
          raise InvalidValueError
        elsif sql.affected_rows == 1
          # If the number of affected_rows is 1 then a new value was inserted
          # thus we can just return the amount given to us since that is the
          # value at the key
          amount
        end
      }
    end

    # del :: String -> nil
    #
    # Deletes the specified key. Returns nil. Raises on error.
    #
    # Example:
    #
    #   kv.del("foo")
    #     # => nil
    #
    def del(key)
      validate_key(key)

      mdel([key])
    end

    # mdel :: String -> nil
    #
    # Deletes the specified keys. Returns nil. Raises on error.
    #
    # Example:
    #
    #   kv.mdel(["foo", "octocat"])
    #     # => nil
    #
    def mdel(keys)
      validate_key_array(keys)

      encapsulate_error do
        GitHub::SQL.run(<<-SQL, :keys => keys, :connection => connection)
          DELETE FROM #{@table_name} WHERE `key` IN :keys
        SQL
      end

      nil
    end

    # ttl :: String -> Result<[Time | nil]>
    #
    # Returns the expires_at time for the specified key or nil.
    #
    # Example:
    #
    #  kv.ttl("foo")
    #    # => #<Result value: 2018-04-23 11:34:54 +0200>
    #
    #  kv.ttl("foo")
    #    # => #<Result value: nil>
    #
    def ttl(key)
      validate_key(key)

      Result.new {
        GitHub::SQL.value(<<-SQL, :key => key, :now => now, :connection => connection)
          SELECT expires_at FROM #{@table_name}
          WHERE `key` = :key AND (expires_at IS NULL OR expires_at > :now)
        SQL
      }
    end

    # mttl :: [String] -> Result<[Time | nil]>
    #
    # Returns the expires_at time for the specified key or nil.
    #
    # Example:
    #
    #  kv.mttl(["foo", "octocat"])
    #    # => #<Result value: [2018-04-23 11:34:54 +0200, nil]>
    #
    def mttl(keys)
      validate_key_array(keys)

      Result.new {
        kvs = GitHub::SQL.results(<<-SQL, :keys => keys, :now => now, :connection => connection).to_h
          SELECT `key`, expires_at FROM #{@table_name}
          WHERE `key` in :keys AND (expires_at IS NULL OR expires_at > :now)
        SQL

        keys.map { |key| kvs[key] }
      }
    end

  private
    def now
      use_local_time ? Time.now : GitHub::SQL::NOW
    end

    def validate_key(key, error_message: nil)
      unless key.is_a?(String)
        raise TypeError, error_message || "key must be a String in #{self.class.name}, but was #{key.class}"
      end

      validate_key_length(key)
    end

    def validate_value(value, error_message: nil)
      unless value.is_a?(String) || value.is_a?(GitHub::SQL::Literal)
        raise TypeError, error_message || "value must be a String in #{self.class.name} or SQL::Literal, but was #{value.class}"
      end

      validate_value_length(value)
    end

    def validate_key_array(keys)
      unless keys.is_a?(Array)
        raise TypeError, "keys must be a [String] in #{self.class.name}, but was #{keys.class}"
      end

      keys.each do |key|
        unless key.is_a?(String)
          raise TypeError, "keys must be a [String] in #{self.class.name}, but also saw at least one #{key.class}"
        end

        validate_key_length(key)
      end
    end

    def validate_key_value_hash(kvs)
      unless kvs.is_a?(Hash)
        raise TypeError, "kvs must be a {String => String} in #{self.class.name}, but was #{kvs.class}"
      end

      kvs.each do |key, value|
        validate_key(key, error_message: "kvs must be a {String => [String | SQL::Literal]} in #{self.class.name}, but also saw at least one key of type #{key.class}")
        validate_value(value, error_message: "kvs must be a {String => [String | SQL::Literal]} in #{self.class.name}, but also saw at least one value of type #{value.class}")
      end
    end

    def validate_key_length(key)
      if key.length > MAX_KEY_LENGTH
        raise KeyLengthError, "key of length #{key.length} exceeds maximum key length of #{MAX_KEY_LENGTH}\n\nkey: #{key.inspect}"
      end
    end

    def validate_value_length(value)
      if value.bytesize > MAX_VALUE_LENGTH
        raise ValueLengthError, "value of length #{value.length} exceeds maximum value length of #{MAX_VALUE_LENGTH}"
      end
    end

    def validate_amount(amount)
      raise ArgumentError.new("The amount specified must be an integer") unless amount.is_a? Integer
      raise ArgumentError.new("The amount specified cannot be 0") if amount == 0
    end

    def validate_touch(touch, expires)
      raise ArgumentError.new("touch_on_insert must be a boolean value") unless [true, false].include?(touch)

      if touch && expires.nil?
        raise ArgumentError.new("Please specify an expires value if you wish to touch on insert")
      end
    end

    def validate_expires(expires)
      unless expires.respond_to?(:to_time)
        raise TypeError, "expires must be a time of some sort (Time, DateTime, ActiveSupport::TimeWithZone, etc.), but was #{expires.class}"
      end
    end

    def encapsulate_error
      yield
    rescue *@encapsulated_errors => error
      raise UnavailableError, "#{error.class}: #{error.message}"
    end
  end
end
