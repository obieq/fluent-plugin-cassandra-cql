require 'simplecov'
require 'rspec'
require 'fluent/test'

# require the library files
Dir["./lib/**/*.rb"].each {|f| require f}

# require the shared example files
Dir["./spec/support/**/*.rb"].each {|f| require f}
