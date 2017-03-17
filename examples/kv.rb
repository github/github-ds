require File.expand_path("../example_setup", __FILE__)
require "github/kv"

# Create new instance using ActiveRecord's default connection.
kv = GitHub::KV.new { ActiveRecord::Base.connection }

# Get a key.
pp kv.get("foo")
#<GitHub::Result:0x3fd88cd3ea9c value: nil>

# Set a key.
kv.set("foo", "bar")
# nil

# Get the key again.
pp kv.get("foo")
#<GitHub::Result:0x3fe810d06e4c value: "bar">

# Get multiple keys at once.
pp kv.mget(["foo", "bar"])
#<GitHub::Result:0x3fccccd1b57c value: ["bar", nil]>

# Check for existence of a key.
pp kv.exists("foo")
#<GitHub::Result:0x3fd4ae55ce8c value: true>

# Check for existence of key that does not exist.
pp kv.exists("bar")
#<GitHub::Result:0x3fd4ae55c554 value: false>

# Check for existence of multiple keys at once.
pp kv.mexists(["foo", "bar"])
#<GitHub::Result:0x3ff1e98e18e8 value: [true, false]>

# Set a key's value if the key does not already exist.
pp kv.setnx("foo", "bar")
# false

# Delete a key.
pp kv.del("bar")
# nil

# Delete multiple keys at once.
pp kv.mdel(["foo", "bar"])
# nil
