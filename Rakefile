require 'rubygems'
require 'bundler'
begin
  Bundler.setup(:default, :development)
rescue Bundler::BundlerError => e
  $stderr.puts e.message
  $stderr.puts "Run `bundle install` to install missing gems"
  exit e.status_code
end
require 'rake'

require 'jeweler'
Jeweler::Tasks.new do |gem|
  # gem is a Gem::Specification... see http://docs.rubygems.org/read/chapter/20 for more options
  gem.name = "silverstripe-deploy"
  gem.homepage = "http://github.com/timsnadden/silverstripe-deploy"
  gem.license = "MIT"
  gem.summary = "Silverstripe specific deployment recipes"
  gem.description = "Silverstripe specific deployment recipes"
  gem.email = "tim@snadden.com"
  gem.authors = ["timsnadden"]
  # Include your dependencies below. Runtime dependencies are required when using your gem,
  # and development dependencies are only needed for development (ie running rake tasks, tests, etc)
  gem.add_runtime_dependency 'capistrano', '>= 2.4'
  gem.add_runtime_dependency 'railsless-deploy', '>= 1.0.2'
  gem.add_development_dependency 'jeweler', '> 1.2.3'
end
