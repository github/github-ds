require "active_record"

module GitHub
  # Public: Build and execute a SQL query, returning results as Arrays. This
  # class uses ActiveRecord's connection classes, but provides a better API for
  # bind values and raw data access.
  #
  # Example:
  #
  #   sql = GitHub::SQL.new(<<-SQL, :parent_ids => parent_ids, :network_id => network_id)
  #     SELECT * FROM repositories
  #     WHERE source_id = :network_id AND parent_id IN :parent_ids
  #   SQL
  #   sql.results
  #   => returns an Array of Arrays, one for each row
  #   sql.hash_results
  #   => returns an Array of Hashes instead
  #
  # Things to be aware of:
  #
  # * `nil` is always considered an error and not a usable value. If you need a
  #    SQL NULL, use the NULL constant instead.
  #
  # * Identical column names in SELECTs will be overridden for hash_results:
  #   `SELECT t1.id, t2.id FROM...` will only return one value for `id`. The
  #   second ID colum won't be included in the hash:
  #
  #   [{ "id" => "1" }]
  #
  #   To get more than one column of the same name, use aliases:
  #   `SELECT t1.id t1_id, t2.id t2_id FROM ...`
  #
  #   Calling `results` however will return an array with all the values:
  #   [[1, 1]]
  #
  # * Arrays are escaped as `(item, item, item)`. If you need to insert multiple
  #   rows (Arrays of Arrays), you must specify the bind value using
  #   GitHub::SQL::ROWS(array_of_arrays).
  #
  class SQL
    # Public: Run inside a transaction. Class version of this method only works
    # if only one connection is in use. If passing connections to
    # GitHub::SQL#initialize or overriding connection then you'll need to use
    # the instance version.
    def self.transaction(options = {}, &block)
      ActiveRecord::Base.connection.transaction(**options, &block)
    end

    # Public: Instantiate a literal SQL value.
    #
    # WARNING: The given value is LITERALLY inserted into your SQL without being
    # escaped, so use this with extreme caution.
    def self.LITERAL(string)
      Literal.new(string)
    end

    # Public: Escape a binary SQL value
    #
    # Used when a column contains binary data which needs to be escaped
    # to prevent warnings from MySQL
    def self.BINARY(string)
      GitHub::SQL.LITERAL(GitHub::SQL.BINARY_LITERAL(string))
    end

    # Public: Escape a binary SQL value, yielding a string which can be used as
    # a literal in SQL
    #
    # Performs the core escaping logic for binary strings in MySQL
    def self.BINARY_LITERAL(string)
      "x'#{string.unpack("H*")[0]}'"
    end

    # Public: Instantiate a list of Arrays of SQL values for insertion.
    def self.ROWS(rows)
      Rows.new(rows)
    end

    # Public: Create and execute a new SQL query, ignoring results.
    #
    # sql      - A SQL string. See GitHub::SQL#add for details.
    # bindings - Optional bind values. See GitHub::SQL#add for details.
    #
    # Returns self.
    def self.run(sql, bindings = {})
      new(sql, bindings).run
    end

    # Public: Create and execute a new SQL query, returning its hash_result rows.
    #
    # sql      - A SQL string. See GitHub::SQL#add for details.
    # bindings - Optional bind values. See GitHub::SQL#add for details.
    #
    # Returns an Array of result hashes.
    def self.hash_results(sql, bindings = {})
      new(sql, bindings).hash_results
    end

    # Public: Create and execute a new SQL query, returning its result rows.
    #
    # sql      - A SQL string. See GitHub::SQL#add for details.
    # bindings - Optional bind values. See GitHub::SQL#add for details.
    #
    # Returns an Array of result arrays.
    def self.results(sql, bindings = {})
      new(sql, bindings).results
    end

    # Public: Create and execute a new SQL query, returning the value of the
    # first column of the first result row.
    #
    # sql      - A SQL string. See GitHub::SQL#add for details.
    # bindings - Optional bind values. See GitHub::SQL#add for details.
    #
    # Returns a value or nil.
    def self.value(sql, bindings = {})
      new(sql, bindings).value
    end

    # Public: Create and execute a new SQL query, returning its values.
    #
    # sql      - A SQL string. See GitHub::SQL#add for details.
    # bindings - Optional bind values. See GitHub::SQL#add for details.
    #
    # Returns an Array of values.
    def self.values(sql, bindings = {})
      new(sql, bindings).values
    end

    # Internal: A Symbol-Keyed Hash of bind values.
    attr_reader :binds

    # Public: The SQL String to be executed. Modified in place.
    attr_reader :query

    # Public: Initialize a new instance.
    #
    # query - An initial SQL string (default: "").
    # binds - A Hash of bind values keyed by Symbol (default: {}).  There are
    #         a couple exceptions.  If they clash with a bind value, add them
    #         in a later #bind or #add call.
    #
    #         :connection     - An ActiveRecord Connection adapter.
    #         :force_timezone - A Symbol describing the ActiveRecord default
    #                           timezone.  Either :utc or :local.
    #
    def initialize(query = nil, binds = nil)
      if query.is_a? Hash
        binds = query
        query = nil
      end

      @last_insert_id = nil
      @affected_rows  = nil
      @binds          = binds ? binds.dup : {}
      @query          = "".dup
      @connection     = @binds.delete :connection
      @force_timezone = @binds.delete :force_timezone

      add query
    end

    # Public: Add a chunk of SQL to the query. Any ":keyword" tokens in the SQL
    # will be replaced with database-safe values from the current binds.
    #
    # sql    - A String containing a fragment of SQL.
    # extras - A Hash of bind values keyed by Symbol (default: {}). These bind
    #          values are only be used to interpolate this SQL fragment,and
    #          aren't available to subsequent adds.
    #
    # Returns self.
    # Raises GitHub::SQL::BadBind for unknown keyword tokens.
    def add(sql, extras = nil)
      return self if sql.nil? || sql.empty?

      query << " " unless query.empty?
      query << interpolate(sql.strip, extras)

      self
    end

    # Public: Add a chunk of SQL to the query, unless query generated so far is empty.
    #
    # Example: use this for conditionally adding UNION when generating sets of SELECTs.
    #
    # sql    - A String containing a fragment of SQL.
    # extras - A Hash of bind values keyed by Symbol (default: {}). These bind
    #          values are only be used to interpolate this SQL fragment,and
    #          aren't available to subsequent adds.
    #
    # Returns self.
    # Raises GitHub::SQL::BadBind for unknown keyword tokens.
    def add_unless_empty(sql, extras = nil)
      return self if query.empty?
      add sql, extras
    end

    # Public: Add additional bind values to be interpolated each time SQL
    # is added to the query.
    #
    # hash - A Symbol-keyed Hash of new values.
    #
    # Returns self.
    def bind(binds)
      self.binds.merge! binds
      self
    end

    # Public: Map each row to an instance of an ActiveRecord::Base subclass.
    def models(klass)
      return @models if defined? @models
      return [] if frozen?

      # Use select_all to retrieve hashes for each row instead of arrays of values.
      @models = connection.
        select_all(query, "#{klass.name} Load via #{self.class.name}").
        map { |record| klass.send :instantiate, record }

      retrieve_found_row_count
      freeze

      @models
    end

    # Public: Execute, memoize, and return the results of this query.
    def results
      return @results if defined? @results
      return [] if frozen?

      enforce_timezone do
        case query
        when /\ADELETE/i
          @affected_rows = connection.delete(query, "#{self.class.name} Delete")

        when /\AINSERT/i
          @last_insert_id = connection.insert(query, "#{self.class.name} Insert")

        when /\AUPDATE/i
          @affected_rows = connection.update(query, "#{self.class.name} Update")

        when /\ASELECT/i
          # Why not execute or select_rows? Because select_all hits the query cache.
          ar_results = connection.select_all(query, "#{self.class.name} Select")
          @hash_results = ar_results.to_ary
          @results = ar_results.rows
        else
          @results = connection.execute(query, "#{self.class.name} Execute").to_a
        end

        @results ||= []

        retrieve_found_row_count
        freeze

        @results
      end
    end

    # Public: Execute, ignoring results. This is useful when the results of a
    # query aren't important, often INSERTs, UPDATEs, or DELETEs.
    #
    # sql    - An optional SQL string. See GitHub::SQL#add for details.
    # extras - Optional bind values. See GitHub::SQL#add for details.
    #
    # Returns self.
    def run(sql = nil, extras = nil)
      add sql, extras if !sql.nil?
      results

      self
    end

    # Public: If the query is a SELECT, return an array of hashes instead of an array of arrays.
    def hash_results
      results
      @hash_results || @results
    end

    # Public: Get first row of results.
    def row
      results.first
    end

    # Public: Get the first column of the first row of results.
    def value
      row && row.first
    end

    # Public: Is there a value?
    def value?
      !value.nil?
    end

    # Public: Get first column of every row of results.
    #
    # Returns an Array or nil.
    def values
      results.map(&:first)
    end

    # Public: Run inside a transaction for the connection.
    def transaction(options = {}, &block)
      connection.transaction(**options, &block)
    end

    # Internal: The object we use to execute SQL and retrieve results. Defaults
    # to AR::B.connection, but can be overridden with a ":connection" key when
    # initializing a new instance.
    def connection
      @connection || ActiveRecord::Base.connection
    end

    # Public: The number of affected rows for this connection.
    def affected_rows
      @affected_rows || connection.raw_connection.affected_rows
    end

    # Public: the number of rows found by the query.
    #
    # Returns FOUND_ROWS() if a SELECT query included SQL_CALC_FOUND_ROWS.
    # Raises if SQL_CALC_FOUND_ROWS was not present in the query.
    def found_rows
      raise "no SQL_CALC_FOUND_ROWS clause present" unless defined? @found_rows
      @found_rows
    end

    # Internal: when a SQL_CALC_FOUND_ROWS clause is present in a SELECT query,
    # retrieve the FOUND_ROWS() value to get a count of the rows sans any
    # LIMIT/OFFSET clause.
    def retrieve_found_row_count
      if query =~ /\A\s*SELECT\s+SQL_CALC_FOUND_ROWS\s+/i
        @found_rows = connection.select_value "SELECT FOUND_ROWS()", self.class.name
      end
    end

    # Public: The last inserted ID for this connection.
    def last_insert_id
      @last_insert_id || connection.raw_connection.last_insert_id
    end

    # Internal: Replace ":keywords" with sanitized values from binds or extras.
    def interpolate(sql, extras = nil)
      sql.gsub(/:[a-z][a-z0-9_]*/) do |raw|
        sym = raw[1..-1].intern # O.o gensym

        if extras && extras.include?(sym)
          val = extras[sym]
        elsif binds.include?(sym)
          val = binds[sym]
        end

        raise BadBind.new raw if val.nil?

        sanitize val
      end
    end

    # Internal: Make `value` database-safe. Ish.
    def sanitize(value)
      case value

      when Integer
        value.to_s

      when Numeric, String
        connection.quote value

      when Array
        raise BadValue.new(value, "an empty array") if value.empty?
        raise BadValue.new(value, "a nested array") if value.any? { |v| v.is_a? Array }

        "(" + value.map { |v| sanitize v }.join(", ") + ")"

      when Literal
        value.value

      when Rows # rows for insertion
        value.values.map { |v| sanitize v }.join(", ")

      when Class
        connection.quote value.name

      when DateTime, Time, Date
        enforce_timezone do
          connection.quote value.to_formatted_s(:db)
        end

      when true
        connection.quoted_true

      when false
        connection.quoted_false

      when Symbol
        connection.quote value.to_s

      else
        raise BadValue, value
      end
    end

    private

    # Private: Forces ActiveRecord's default timezone for duration of block.
    def enforce_timezone(&block)
      on_rails_7 = ActiveRecord.respond_to?(:default_timezone)
      begin
        if @force_timezone
          if on_rails_7
            zone = ActiveRecord.default_timezone
            ActiveRecord.default_timezone = @force_timezone
          else
            zone = ActiveRecord::Base.default_timezone
            ActiveRecord::Base.default_timezone = @force_timezone
          end
        end

        yield if block_given?
      ensure
        if on_rails_7
          ActiveRecord.default_timezone = zone if @force_timezone
        else
          ActiveRecord::Base.default_timezone = zone if @force_timezone
        end
      end
    end
  end
end

require "github/sql/literal"
require "github/sql/rows"
require "github/sql/errors"
