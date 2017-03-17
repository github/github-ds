require File.expand_path("../example_setup", __FILE__)
require "github/result"

def some_successful_computation
  1
end

def some_failing_computation
  raise "noooooppppeeeee"
end

result = GitHub::Result.new { some_successful_computation }
p result.ok? # => true
p result.value! # => 1

result = GitHub::Result.new { some_failing_computation }
p result.ok? # => false
p result.value { "default when error happens" } # => "default when error happens"

begin
  result.value! # raises exception because error happeend
rescue => error
  p result.error
  p error
end

result = GitHub::Result.new {
  GitHub::Result.new { puts "Step 1: success!" }
}.then { |value|
  GitHub::Result.new { puts "Step 2: success!" }
}.then { |value|
  GitHub::Result.new { puts "Step 3: success!" }
}
p result.ok?

result = GitHub::Result.new {
  GitHub::Result.new { puts "Step 1: success!" }
}.then { |value|
  GitHub::Result.new {
    puts "Step 2: failed!"
    raise
  }
}.then { |value|
  GitHub::Result.new {
    puts "Step 3: should not get here because previous step failed!"
  }
}
p result.ok?
