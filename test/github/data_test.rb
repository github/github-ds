require 'test_helper'

class Github::DataTest < Minitest::Test
  def test_that_it_has_a_version_number
    refute_nil ::Github::Data::VERSION
  end
end
