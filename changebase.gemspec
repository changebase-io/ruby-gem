require_relative "lib/changebase/version"

Gem::Specification.new do |s|
  s.name        = "changebase"
  s.version     = Changebase::VERSION
  s.authors     = ["Jon Bracy", "James Bracy"]
  s.email       = ["jonbracy@gmail.com", "waratuman@gmail.com"]
  s.homepage    = "https://changebase.io"
  s.summary     = %q{Changebase.io Client}
  s.description = %q{Ruby library for integrating with Changebase.io}

  s.files         = Dir["LICENSE", "README.md", "lib/**/*"]
  s.require_paths = ["lib"]
  s.test_files    = []
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  
  s.extra_rdoc_files = %w(README.rdoc)
  s.rdoc_options.concat ['--main', 'README.rdoc']

  # Developoment 
  s.add_development_dependency 'rake'
  s.add_development_dependency 'byebug'
  s.add_development_dependency 'bundler'
  s.add_development_dependency 'minitest'
  s.add_development_dependency 'minitest-reporters'
  s.add_development_dependency 'mocha'
  s.add_development_dependency 'faker'
  s.add_development_dependency 'factory_bot'
  s.add_development_dependency 'simplecov'
  
  # Runtime
  s.add_runtime_dependency 'activerecord', '>= 6'
  
  s.add_development_dependency 'pg'
end