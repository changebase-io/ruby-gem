require_relative "lib/changebase/version"

Gem::Specification.new do |spec|
  spec.name        = "changebase"
  spec.authors     = ["Jon Bracy", "James Bracy"]
  spec.email       = ["jon@changebase.io", "james@changebase.io"]
  spec.summary     = %q{Changebase.io Client}
  spec.description = %q{Ruby library for integrating with Changebase.io}
  spec.homepage    = "https://changebase.io"
  
  spec.metadata["homepage_uri"]       = spec.homepage
  spec.metadata["source_code_uri"]    = "https://github.com/changebase-io/ruby-gem"
  spec.metadata["bug_tracker_uri"]    = "https://github.com/changebase-io/ruby-gem/issues"
  # spec.metadata["changelog_uri"]      = "#{spec.homepage}/blob/master/CHANGELOG.md"
  # spec.metadata["documentation_uri"]  = "#{spec.homepage}/blob/master/CHANGELOG.md"

  spec.version     = Changebase::VERSION
  spec.platform    = Gem::Platform::RUBY
  spec.required_ruby_version = '>= 2.7'
  
  spec.files         = Dir["README.md", "lib/**/*", "db/**/*"]
  spec.require_paths = ["lib"]
  
  spec.extra_rdoc_files = %w(README.md)
  spec.rdoc_options.concat ['--main', 'README.md']
  
  # Runtime
  spec.add_runtime_dependency 'activerecord',  '>= 5.2', '< 8'
  spec.add_runtime_dependency 'actionpack',    '>= 5.2', '< 8'
  spec.add_runtime_dependency 'railties',      '>= 5.2', '< 8'

  # Developoment 
  spec.add_development_dependency 'rake'
  spec.add_development_dependency 'byebug'
  spec.add_development_dependency 'bundler'
  spec.add_development_dependency 'minitest'
  spec.add_development_dependency 'minitest-reporters'
  spec.add_development_dependency 'webmock'
  spec.add_development_dependency 'mocha'
  spec.add_development_dependency 'faker'
  spec.add_development_dependency 'factory_bot'
  spec.add_development_dependency 'simplecov'
  spec.add_development_dependency 'pg'
end