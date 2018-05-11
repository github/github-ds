source "https://rubygems.org"
gemspec

DEFAULT_RAILS_VERSION = '5.0.2'

if ENV['RAILS_VERSION'] = '4.2.10'
  gem 'mysql2', '~> 0.3.18'
else
  gem "mysql2"
end
gem "rails", "~> #{ENV['RAILS_VERSION'] || DEFAULT_RAILS_VERSION}"
gem "activerecord", "~> #{ENV['RAILS_VERSION'] || DEFAULT_RAILS_VERSION}"
