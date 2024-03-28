# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require "github/ds/version"

Gem::Specification.new do |spec|
  spec.name          = "github-ds"
  spec.version       = GitHub::DS::VERSION
  spec.authors       = ["GitHub Open Source", "John Nunemaker"]
  spec.email         = ["opensource+github-ds@github.com", "nunemaker@gmail.com"]

  spec.summary       = %q{A collection of libraries for working with SQL on top of ActiveRecord's connection.}
  spec.description   = %q{A collection of libraries for working with SQL on top of ActiveRecord's connection.}
  spec.homepage      = "https://github.com/github/github-ds"
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

  spec.add_dependency "activerecord", ">= 3.2"

  spec.add_development_dependency "bundler", ">= 1.14"
  spec.add_development_dependency "rake"
  spec.add_development_dependency "minitest"
  spec.add_development_dependency "timecop"
  spec.add_development_dependency "activesupport"
  spec.add_development_dependency "mysql2"
  spec.add_development_dependency "mocha"
end
