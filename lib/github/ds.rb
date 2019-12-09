require_relative "ds/version"
require_relative "ds/config"

module GitHub
  module DS
    class << self
      attr_writer :config
    end

    def self.config
      @config ||= Config.new
    end

    def self.reset
      @config = Config.new
    end

    def self.configure
      yield(config)
    end
  end
end

require_relative "kv"
