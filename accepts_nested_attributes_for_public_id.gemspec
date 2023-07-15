require_relative 'lib/accepts_nested_attributes_for_public_id/version'

Gem::Specification.new do |s|
  s.name          = "accepts_nested_attributes_for_public_id"
  s.version       = "1.0.0"
  s.authors       = ["Weston Ganger"]
  s.email         = ["weston@westonganger.com"]

  s.summary       = "A patch for Rails to support using a public ID column instead of ID for use with accepts_nested_attributes_for"
  s.description   = s.summary
  s.homepage      = "https://github.com/westonganger/accepts_nested_attributes_for_public_id"
  s.license       = "MIT"

  s.metadata["source_code_uri"] = s.homepage
  s.metadata["changelog_uri"] = File.join(s.homepage, "blob/master/CHANGELOG.md")

  s.files = Dir.glob("{lib/**/*}") + %w{ LICENSE README.md Rakefile CHANGELOG.md }
  s.require_path = 'lib'

  s.add_runtime_dependency "activerecord", ">= 5.0.0"
  s.add_runtime_dependency "actionview", ">= 5.0.0"

  s.add_development_dependency "rake"
  s.add_development_dependency "rspec-rails"
  s.add_development_dependency "database_cleaner"
  s.add_development_dependency "rails-controller-testing"
  s.add_development_dependency "rails"
  s.add_development_dependency "warning"
  s.add_development_dependency "pry-rails"
end
