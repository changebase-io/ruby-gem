# require 'bundler/setup'
# require "bundler/gem_tasks"
# # Bundler.require(:development)
require 'rake/testtask'
require 'rdoc/task'

ADAPTERS = %w(replication inline)

MAJORS =  %w(7.0.2 6.1.5 6.0.4 5.2.7)

MINORS =  %w(7.0.0 7.0.1 7.0.2) +
          %w(6.1.0 6.1.1 6.1.2 6.1.3 6.1.4 6.1.5) +
          %w(6.0.0 6.0.1 6.0.2 6.0.3 6.0.4) +
          %w(5.2.0 5.2.1 5.2.2 5.2.3 5.2.4 5.2.5 5.2.6 5.2.7)

# task :coverage do
#   require 'simplecov'
#   SimpleCov.start do
#     add_group 'lib', 'lib'
#     add_group 'ext', 'ext'
#     add_filter "/test"
#   end
# end

# Test Task
namespace :test do
  MINORS.each do |version|
    namespace version do
      ADAPTERS.each do |adapter|
        Rake::TestTask.new(adapter => ["test:#{version}", "test:#{adapter}"]) do |t|
          t.libs << 'lib' << 'test'
          t.test_files = FileList[(File.file?(ARGV.last) || ARGV.index('*')) ? ARGV.last : 'test/**/*_test.rb']
          t.warning = true
          t.verbose = false
        end
      end
    end

    task(version) do
      installed_version = `gem list -e rails`.lines.last.match(/\(([^\)]+)\)/)[1].split(", ")
      if !installed_version.include?(version)
        `gem install rails -v #{version}`
      end
      ENV['RAILS_VERSION'] = version
    end
  end

  ADAPTERS.each do |adapter|
    task(adapter) { ENV["CB_ADAPTER"] = adapter }
  end

  task majors: MAJORS.shuffle.map { |v| "test:#{v}" }
  task minors: MINORS.shuffle.map { |v| "test:#{v}" }
end

task :test => "test:minors"
