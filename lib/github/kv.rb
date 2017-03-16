require "github/kv/version"
require "github/kv/result"
require "github/kv/sql"

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
#     error rather than raising the exception directly. See lib/github/kv/result.rb
#     for more documentation on GitHub::KV::Result including usage examples.
#
#     When using GitHub::KV, it's important to handle error conditions and not
#     assume that GitHub::KV::Result objects will always represent success.
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

    class MissingConnectionError < StandardError; end

    def initialize(encapsulated_errors = [SystemCallError], &conn_block)
      @encapsulated_errors = encapsulated_errors
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
        kvs = GitHub::KV::SQL.results(<<-SQL, :keys => keys, :connection => connection).to_h
          SELECT `key`, value FROM key_values WHERE `key` IN :keys AND (`expires_at` IS NULL OR `expires_at` > NOW())
        SQL

        keys.map { |key| kvs[key] }
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
        [key, value, GitHub::KV::SQL::NOW, GitHub::KV::SQL::NOW, expires || GitHub::KV::SQL::NULL]
      }

      encapsulate_error do
        GitHub::KV::SQL.run(<<-SQL, :rows => GitHub::KV::SQL::ROWS(rows), :connection => connection)
          INSERT INTO key_values (`key`, value, created_at, updated_at, expires_at)
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
        existing_keys = GitHub::KV::SQL.values(<<-SQL, :keys => keys, :connection => connection).to_set
          SELECT `key` FROM key_values WHERE `key` IN :keys AND (`expires_at` IS NULL OR `expires_at` > NOW())
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

        GitHub::KV::SQL.run(<<-SQL, :key => key, :connection => connection)
          DELETE FROM key_values WHERE `key` = :key AND expires_at <= NOW()
        SQL

        sql = GitHub::KV::SQL.run(<<-SQL, :key => key, :value => value, :expires => expires || GitHub::KV::SQL::NULL, :connection => connection)
          INSERT IGNORE INTO key_values (`key`, value, created_at, updated_at, expires_at)
          VALUES (:key, :value, NOW(), NOW(), :expires)
        SQL

        sql.affected_rows > 0
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
        GitHub::KV::SQL.run(<<-SQL, :keys => keys, :connection => connection)
          DELETE FROM key_values WHERE `key` IN :keys
        SQL
      end

      nil
    end

  private
    def validate_key(key)
      raise TypeError, "key must be a String in #{self.class.name}, but was #{key.class}" unless key.is_a?(String)

      validate_key_length(key)
    end

    def validate_value(value)
      raise TypeError, "value must be a String in #{self.class.name}, but was #{value.class}" unless value.is_a?(String)

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
        raise TypeError, "kvs must be a {String => String} in #{self.class.name}, but was #{key.class}"
      end

      kvs.each do |key, value|
        unless key.is_a?(String)
          raise TypeError, "kvs must be a {String => String} in #{self.class.name}, but also saw at least one key of type #{key.class}"
        end

        unless value.is_a?(String)
          raise TypeError, "kvs must be a {String => String} in #{self.class.name}, but also saw at least one value of type #{value.class}"
        end

        validate_key_length(key)
        validate_value_length(value)
      end
    end

    def validate_key_length(key)
      if key.length > MAX_KEY_LENGTH
        raise KeyLengthError, "key of length #{key.length} exceeds maximum key length of #{MAX_KEY_LENGTH}\n\nkey: #{key.inspect}"
      end
    end

    def validate_value_length(value)
      if value.length > MAX_VALUE_LENGTH
        raise ValueLengthError, "value of length #{value.length} exceeds maximum value length of #{MAX_VALUE_LENGTH}"
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
