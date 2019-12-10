require "test_helper"

class GitHub::DSTest < Minitest::Test
  def setup
    GitHub::DS.reset
  end

  def teardown
    GitHub::DS.reset
  end

  def test_configures_correctly
    GitHub::DS.configure do |config|
      config.table_name = "example_key_values"
    end

    assert_equal GitHub::DS.config.table_name, "example_key_values"
  end

  def test_resets_correctly
    GitHub::DS.configure do |config|
      config.table_name = "example_key_values"
    end

    GitHub::DS.reset
    refute_equal GitHub::DS.config.table_name, "example_key_values"
    assert_equal GitHub::DS.config.table_name, "key_values"
  end
end
