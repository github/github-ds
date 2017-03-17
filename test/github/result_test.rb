require 'test_helper'

class GitHub::ResultTest < Minitest::Test
  def test_to_s
    assert_match %r{#<GitHub::Result:0x[a-f0-9]+ value: 123>}, GitHub::Result.new { 123 }.to_s

    assert_match %r{#<GitHub::Result:0x[a-f0-9]+ error: #<RuntimeError: nope>>}, GitHub::Result.new { raise "nope" }.to_s
  end

  def test_then
    assert_equal 456, GitHub::Result.new { 123 }.then {
      GitHub::Result.new { 456 }
    }.value!

    assert GitHub::Result.new { raise "nope" }.then {
      flunk "should not have invoked then block"
    }.error

    assert_raises TypeError do
      GitHub::Result.new {}.then {
        "not a result"
      }
    end
  end

  def test_rescue
    assert_equal 456, GitHub::Result.new { raise "nope" }.rescue {
      GitHub::Result.new { 456 }
    }.value!

    assert_equal 456, GitHub::Result.new { raise "nope" }.rescue { |error|
      assert_equal "nope", error.message
      GitHub::Result.new { 456 }
    }.value!

    assert GitHub::Result.new { 123 }.rescue {
      flunk "should not have invoked rescue block"
    }.value!

    assert_raises TypeError do
      GitHub::Result.new { raise "nope" }.rescue {
        "not a result"
      }
    end
  end

  def test_map
    assert_equal 456, GitHub::Result.new { 123 }.map {
      456
    }.value!

    assert GitHub::Result.new { raise "nope" }.map {
      flunk "should not have invoked map block"
    }.error
  end

  def test_value
    assert_equal 123, GitHub::Result.new { 123 }.value { 456 }

    assert_equal 456, GitHub::Result.new { raise "nope" }.value { 456 }
  end

  def test_value!
    assert_equal 123, GitHub::Result.new { 123 }.value!

    r = GitHub::Result.new { raise "nope" }

    assert_raises RuntimeError do
      r.value!
    end
  end

  def test_ok?
    assert_predicate GitHub::Result.new { 123 }, :ok?

    refute_predicate GitHub::Result.new { raise "nope" }, :ok?
  end

  def test_error
    assert_nil GitHub::Result.new { 123 }.error

    e = StandardError.new("nope")

    assert_equal e, GitHub::Result.new { raise e }.error
  end
end
