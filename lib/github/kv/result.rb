module GitHub
  class KV
    class Result
      # Invokes the supplied block and wraps the return value in a
      # GitHub::KV::Result object.
      #
      # Exceptions raised by the block are caught and also wrapped.
      #
      # Example:
      #
      #   GitHub::KV::Result.new { 123 }
      #     # => #<GitHub::KV::Result value: 123>
      #
      #   GitHub::KV::Result.new { raise "oops" }
      #     # => #<GitHub::KV::Result error: #<RuntimeError: oops>>
      #
      def initialize
        begin
          @value = yield
          @error = nil
        rescue => e
          @error = e
        end
      end

      def to_s
        if ok?
          "#<GitHub::KV::Result:0x%x value: %s>" % [object_id, @value.inspect]
        else
          "#<GitHub::KV::Result:0x%x error: %s>" % [object_id, @error.inspect]
        end
      end

      alias_method :inspect, :to_s

      # If the result represents a value, invokes the supplied block with
      # that value.
      #
      # If the result represents an error, returns self.
      #
      # The block must also return a GitHub::KV::Result object.
      # Use #map otherwise.
      #
      # Example:
      #
      #   result = do_something().then { |val|
      #     do_other_thing(val)
      #   }
      #     # => #<GitHub::KV::Result value: ...>
      #
      #   do_something_that_fails().then { |val|
      #     # never invoked
      #   }
      #     # => #<GitHub::KV::Result error: ...>
      #
      def then
        if ok?
          result = yield(@value)
          raise TypeError, "block invoked in GitHub::KV::Result#then did not return GitHub::KV::Result" unless result.is_a?(Result)
          result
        else
          self
        end
      end

      # If the result represents an error, invokes the supplied block with that error.
      #
      # If the result represents a value, returns self.
      #
      # The block must also return a GitHub::KV::Result object.
      # Use #map otherwise.
      #
      # Example:
      #
      #   result = do_something().rescue { |val|
      #     # never invoked
      #   }
      #     # => #<GitHub::KV::Result value: ...>
      #
      #   do_something_that_fails().rescue { |val|
      #     # handle_error(val)
      #   }
      #     # => #<GitHub::KV::Result error: ...>
      #
      def rescue
        return self if ok?
        result = yield(@error)
        raise TypeError, "block invoked in GitHub::KV::Result#rescue did not return GitHub::KV::Result" unless result.is_a?(Result)
        result
      end

      # If the result represents a value, invokes the supplied block with that
      # value and wraps the block's return value in a GitHub::KV::Result.
      #
      # If the result represents an error, returns self.
      #
      # The block should not return a GitHub::KV::Result object (unless you
      # truly intend to create a GitHub::KV::Result<GitHub::KV::Result<T>>).
      # Use #then if it does.
      #
      # Example:
      #
      #   result = do_something()
      #     # => #<GitHub::KV::Result value: 123>
      #
      #   result.map { |val| val * 2 }
      #     # => #<GitHub::KV::Result value: 246>
      #
      #   do_something_that_fails().map { |val|
      #     # never invoked
      #   }
      #     # => #<GitHub::KV::Result error: ...>
      #
      def map
        if ok?
          Result.new { yield(@value) }
        else
          self
        end
      end

      # If the result represents a value, returns that value.
      #
      # If the result represents an error, invokes the supplied block with the
      # exception object.
      #
      # Example:
      #
      #   result = do_something()
      #     # => #<GitHub::KV::Result value: "foo">
      #
      #   result.value { "nope" }
      #     # => "foo"
      #
      #   result = do_something_that_fails()
      #     # => #<GitHub::KV::Result error: ...>
      #
      #   result.value { "nope" }
      #     # => #<GitHub::KV::Result value: "nope">
      #
      def value
        unless block_given?
          raise ArgumentError, "must provide a block to GitHub::KV::Result#value to be invoked in case of error"
        end

        if ok?
          @value
        else
          yield(@error)
        end
      end

      # If the result represents a value, returns that value.
      #
      # If the result represents an error, raises that error.
      #
      # Example:
      #
      #   result = do_something()
      #     # => #<GitHub::KV::Result value: "foo">
      #
      #   result.value!
      #     # => "foo"
      #
      #   result = do_something_that_fails()
      #     # => #<GitHub::KV::Result error: ...>
      #
      #   result.value!
      #     # !! raises exception
      #
      def value!
        if ok?
          @value
        else
          raise @error
        end
      end

      # Returns true if the result represents a value, false if an error.
      #
      # Example:
      #
      #   result = do_something()
      #     # => #<GitHub::KV::Result value: "foo">
      #
      #   result.ok?
      #     # => true
      #
      #   result = do_something_that_fails()
      #     # => #<GitHub::KV::Result error: ...>
      #
      #   result.ok?
      #     # => false
      #
      def ok?
        !@error
      end

      # If the result represents a value, returns nil.
      #
      # If the result represents an error, returns that error.
      #
      #   result = do_something()
      #     # => #<GitHub::KV::Result value: "foo">
      #
      #   result.error
      #     # => nil
      #
      #   result = do_something_that_fails()
      #     # => #<GitHub::KV::Result error: ...>
      #
      #   result.error
      #     # => ...
      #
      def error
        @error
      end

      # Create a GitHub::KV::Result with only the error condition set.
      #
      #    GitHub::KV::Result.error(e)
      #     # => # <GitHub::KV::Result error: ...>
      #
      def self.error(e)
        result = allocate
        result.instance_variable_set(:@error, e)
        result
      end
    end
  end
end
