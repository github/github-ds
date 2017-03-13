# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'github/data/version'

Gem::Specification.new do |spec|
  spec.name          = "github-data"
  spec.version       = Github::Data::VERSION
  spec.authors       = ["John Nunemaker"]
  spec.email         = ["nunemaker@gmail.com"]

  spec.summary       = %q{Useful tools for working with SQL data.}
  spec.description   = %q{Useful tools for working with SQL data.}
  spec.homepage      = "https://github.com/github/github-data"
  spec.license       = "MIT"

  # Prevent pushing this gem to RubyGems.org. To allow pushes either set the 'allowed_push_host'
  # to allow pushing to a single host or delete this section to allow pushing to any host.
  if spec.respond_to?(:metadata)
    spec.metadata['allowed_push_host'] = "https://rubygems.org"
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
  spec.add_development_dependency "activerecord-mysql2-adapter"
  spec.add_development_dependency "mysql2", "~> 0.3.10"
end
