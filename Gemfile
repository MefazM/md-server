source 'https://rubygems.org'
gem 'instrumental_agent'
gem "eventmachine", "~> 1.0.3"


gem 'mysql2', platform: :ruby

gem 'pry'

if defined?(JRUBY_VERSION)
  gem 'jdbc-mysql'
  gem "redis", "~> 3.0.1"
  gem "hiredis", "~> 0.4.5"
  gem "json-jruby"
else
  gem 'mysql2'
  
  gem 'pry-stack_explorer'
  gem 'pry-debugger'

  gem "redis", "~> 3.0.5"
  gem 'yajl-ruby'
end

