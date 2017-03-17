require File.expand_path("../example_setup", __FILE__)
require "github/result"

def do_something
  1
end

def do_something_that_errors
  raise "noooooppppeeeee"
end

result = GitHub::Result.new { do_something }
p result.ok? # => true
p result.value! # => 1

result = GitHub::Result.new { do_something_that_errors }
p result.ok? # => false
p result.value { "default when error happens" } # => "default when error happens"

begin
  result.value! # => raises exception because error happened
rescue => error
  p result.error # => the error
  p error # the same error
end

# Outputs Step 1, 2, 3
result = GitHub::Result.new {
  GitHub::Result.new { puts "Step 1: success!" }
}.then { |value|
  GitHub::Result.new { puts "Step 2: success!" }
}.then { |value|
  GitHub::Result.new { puts "Step 3: success!" }
}
p result.ok? # => true

# Outputs Step 1, 2 and stops.
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
p result.ok? # => false
