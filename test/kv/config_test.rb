require "test_helper"

class GitHub::KV::ConfigTest < Minitest::Test
  def test_default_value_is_correct
    configuration = GitHub::KV::Config.new

    assert_equal configuration.table_name, "key_values"
  end

  def test_can_change_value
    configuration = GitHub::KV::Config.new
    configuration.table_name = "some_key_values"
    assert_equal configuration.table_name, "some_key_values"
  end
end
