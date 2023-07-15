require File.expand_path(File.dirname(__FILE__) + '/lib/accepts_nested_attributes_for_public_id/version.rb')
require "bundler/gem_tasks"

### Allow to use dummy app rake/rails commands from gem base folder
APP_RAKEFILE = File.expand_path("spec/dummy_app/Rakefile", __dir__)
load 'rails/tasks/engine.rake'

require 'rspec/core/rake_task'
RSpec::Core::RakeTask.new(:spec)

task test: [:spec]

task default: [:spec]
