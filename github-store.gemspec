# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require "github/store/version"

Gem::Specification.new do |spec|
  spec.name          = "github-store"
  spec.version       = GitHub::Store::VERSION
  spec.authors       = ["GitHub Open Source", "John Nunemaker"]
  spec.email         = ["opensource+github-store@github.com", "nunemaker@gmail.com"]

  spec.summary       = %q{A key/value data store backed by MySQL.}
  spec.description   = %q{A key/value data store backed by MySQL.}
  spec.homepage      = "https://github.com/github/github-store"
  spec.license       = "MIT"

  # Prevent pushing this gem to RubyGems.org. To allow pushes either set the 'allowed_push_host'
  # to allow pushing to a single host or delete this section to allow pushing to any host.
  if spec.respond_to?(:metadata)
    spec.metadata["allowed_push_host"] = "https://rubygems.org"
  else
    raise "RubyGems 2.0 or newer is required to protect against " \
      "public gem pushes."
  end

  spec.files         = `git ls-files -z`.split("\x0").reject do |f|
    f.match(%r{^(test|spec|features)/})
  end
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler", "~> 1.14"
  spec.add_development_dependency "rake", "~> 10.0"
  spec.add_development_dependency "minitest", "~> 5.0"
  spec.add_development_dependency "timecop", "~> 0.8.1"
  spec.add_development_dependency "activerecord", "~> 5.0"
  spec.add_development_dependency "activesupport"
  spec.add_development_dependency "mysql2"
  spec.add_development_dependency "activerecord-mysql-adapter"
  spec.add_development_dependency "mocha", "~> 1.2.1"
end
