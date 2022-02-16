require 'bundler/setup'
require "bundler/gem_tasks"
Bundler.require(:development)
require 'rake/testtask'
require 'rdoc/task'

Rake::TestTask.new do |t|
    t.libs << 'test'
    t.test_files = FileList['test/**/*_test.rb']
    t.warning = true
    #t.verbose = true
end