module GitHub
  class SQL
    # Internal: a SQL literal value.
    class Literal
      # Public: the string value of this literal
      attr_reader :value

      def initialize(value)
        @value = value.to_s.dup.freeze
      end

      def inspect
        "<#{self.class.name} #{value}>"
      end

      def bytesize
        value.bytesize
      end
    end

    # Public: prepackaged literal values.
    NULL = Literal.new "NULL"
    NOW  = Literal.new "NOW()"
  end
end
