module GitHub
  module DS
    class Config
      attr_accessor :table_name

      def initialize
        @table_name = 'key_values'
      end
    end
  end
end
