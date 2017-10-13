module GitHub
  class SQL
    # Public: A superclass for errors.
    class Error < RuntimeError
    end

    # Public: Raised when a bound ":keyword" value isn't available.
    class BadBind < Error
      def initialize(keyword)
        super "There's no bind value for #{keyword.inspect}"
      end
    end

    # Public: Raised when a bound value can't be sanitized.
    class BadValue < Error
      def initialize(value, description = nil)
        description ||= "a #{value.class.name}"
        super "Can't sanitize #{description}: #{value.inspect}"
      end
    end
  end
end
