require 'rake/testtask'
require 'rdoc/task'

ADAPTERS = %w(replication_by_message replication_by_table inline_by_api)

MAJORS =  %w(8.0.1 7.2.2 7.1.2 7.0.4 6.1.7)

MINORS =  %w(8.0.1) +
          %w(7.1.2) +
          %w(7.0.1 7.0.2 7.0.3 7.0.4) +
          %w(6.1.0 6.1.1 6.1.2 6.1.3 6.1.4 6.1.5 6.1.6 6.1.7)
# task :coverage do
#   require 'simplecov'
#   SimpleCov.start do
#     add_group 'lib', 'lib'
#     add_group 'ext', 'ext'
#     add_filter "/test"
#   end
# end

namespace :setup do
  MINORS.each do |version|
    task(version) do
      ENV['RAILS_VERSION'] = version
    end
  end

  ADAPTERS.each do |adapter|
    task(adapter) { ENV["CB_ADAPTER"] = adapter }
  end
end

# Test Task
namespace :test do
  MINORS.each do |version|
    namespace version do
      ADAPTERS.each do |adapter|
        Rake::TestTask.new(adapter => ["setup:#{version}", "setup:#{adapter}"]) do |t|
          t.libs << 'lib' << 'test'
          t.test_files = FileList[(File.file?(ARGV.last) || ARGV.index('*')) ? ARGV.last : 'test/**/*_test.rb']
          t.warning = true
          t.verbose = false
        end
      end
    end

    desc "Run test for Rails #{version}"
    task version => ADAPTERS.shuffle.map { |a| "test:#{version}:#{a}" }
  end

  ADAPTERS.each do |adapter|
    desc "Run test for #{adapter} Adatper"
    task adapter => MINORS.shuffle.map { |v| "test:#{v}:#{adapter}" }
  end

  task majors: MAJORS.shuffle.map { |v| "test:#{v}" }
  task minors: MINORS.shuffle.map { |v| "test:#{v}" }
end

task :test => "test:minors"
