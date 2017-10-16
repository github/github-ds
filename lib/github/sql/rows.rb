module GitHub
  class SQL
    # Internal: a list of arrays of values for insertion into SQL.
    class Rows
      # Public: the Array of row values
      attr_reader :values

      def initialize(values)
        unless values.all? { |v| v.is_a? Array }
          raise ArgumentError, "cannot instantiate SQL rows with anything but arrays"
        end
        @values = values.dup.freeze
      end

      def inspect
        "<#{self.class.name} #{values.inspect}>"
      end
    end
  end
end
