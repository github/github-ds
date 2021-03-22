module GitHub
  class KV
    class Config
      attr_accessor :table_name, :encapsulated_errors, :use_local_time
      attr_writer :case_sensitive

      def initialize
        @table_name = 'key_values'
        @encapsulated_errors = [SystemCallError]
        @use_local_time = false
        @case_sensitive = false
        yield self if block_given?
      end

      def case_sensitive?
        @case_sensitive
      end
    end
  end
end
