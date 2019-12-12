module GitHub
  class KV
    class Config
      attr_accessor :table_name, :encapsulated_errors, :use_local_time

      def initialize
        @table_name = 'key_values'
        @encapsulated_errors = [SystemCallError]
        @use_local_time = false
      end
    end
  end
end
