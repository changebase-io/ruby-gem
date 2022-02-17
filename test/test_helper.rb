# To make testing/debugging easier, test within this source tree versus an
# installed gem
$LOAD_PATH << File.expand_path('../lib', __FILE__)

require 'simplecov'
SimpleCov.start

require 'byebug'
require "minitest/autorun"
require 'minitest/unit'
require 'minitest/reporters'
require 'mocha/minitest'

require "rails"
require "action_controller/railtie"
require "active_record"
require "action_controller"
require "action_controller/base"

require 'changebase'
require 'changebase/action_controller'
require 'changebase/active_record'

Rails.env = 'test'

Minitest::Reporters.use! Minitest::Reporters::SpecReporter.new

$debugging = false

class ActionDispatch::IntegrationTest
  
  def setup
    @routes ||= self.class.app.routes
  end
  
  def self.app
    return @app if @app
    
    @app = Class.new(Rails::Application) do
      config.eager_load = true
      config.cache_classes = true
      config.secret_key_base = 'test key base'

      # config.logger = Logger.new($stdout)
      # Rails.logger = config.logger
    end
    
    route_namespace = self.name
    route_routes = @routes
    @app.routes.append do
      scope module: route_namespace.underscore do
        route_routes.each do |route|
          case route
          when Array
            send(route[0], *route[1], &route[2])
          else
            instance_exec(&route)
          end
        end
      end
    end

    app.initialize!
  end
  
  def self.routes(&block)
    @routes ||= []
    @routes << block
  end
  
  def self.get(*args, &block)
    @routes ||= []
    @routes << [:get, args, block]
  end
end

# File 'lib/active_support/testing/declarative.rb', somewhere in rails....
class ActiveSupport::TestCase
  # include WebMock::API
  
  # File 'lib/active_support/testing/declarative.rb'
  def self.test(name, &block)
    test_name = "test_#{name.gsub(/\s+/, '_')}".to_sym
    defined = method_defined? test_name
    raise "#{test_name} is already defined in #{self}" if defined
    if block_given?
      define_method(test_name, &block)
    else
      define_method(test_name) do
        skip "No implementation provided for #{name}"
      end
    end
  end
  
  # AR Setup
  def self.schema(&block)
    self.class_variable_set(:@@schema, block)
  end
  
  set_callback(:setup, :before) do
    if !self.class.class_variable_defined?(:@@suite_setup_run) && self.class.class_variable_defined?(:@@schema)
      ar_config = {
        adapter:  "postgresql",
        database: "changebase-ruby-gem-test",
        encoding: "utf8"
      }
    
      ActiveRecord::Base.establish_connection(ar_config)
      db_config = if ActiveRecord.version < Gem::Version.new('6.1')
        ActiveRecord::Base.connection_config.stringify_keys
      else
        ActiveRecord::Base.connection_db_config
      end
      
      db_tasks = ActiveRecord::Tasks::PostgreSQLDatabaseTasks.new(db_config)
      begin
        db_tasks.purge
      rescue ActiveRecord::NoDatabaseError
        db_tasks.create
      end
      
      ActiveRecord::Migration.suppress_messages do
        ActiveRecord::Schema.define(&self.class.class_variable_get(:@@schema))
        ActiveRecord::Migration.execute("SELECT c.relname FROM pg_class c WHERE c.relkind = 'S'").each_row do |row|
          ActiveRecord::Migration.execute("ALTER SEQUENCE #{row[0]} RESTART WITH #{rand(50_000)}")
        end
      end
    end
    
    self.class.class_variable_set(:@@suite_setup_run, true)
  end
  
  def debug
    ActiveRecord::Base.logger = Logger.new(STDOUT)
    $debugging = true
    yield
  ensure
    ActiveRecord::Base.logger = nil
    $debugging = false
  end

  def assert_sql(expected, query)
    assert_equal expected.strip.gsub(/"(\w+)"/, '\1').gsub(/[\s]+/, ' '), query.to_sql.strip.gsub(/"(\w+)"/, '\1').gsub(/[\s]+/, ' ')
  end

  def capture_sql
    queries_ran = SQLLogger.log.size
    yield
    SQLLogger.log[queries_ran...]
  end
  
  def assert_query(*expected)
    queries_ran = SQLLogger.log.size

    yield

    failed_patterns = []
    queries_ran = SQLLogger.log[queries_ran...]
    
    expected.each do |pattern|
      failed_patterns << pattern unless queries_ran.any?{ |sql| pattern === sql }
    end

    assert failed_patterns.empty?, <<~MSG
      Query pattern(s) not found:
        - #{failed_patterns.map(&:inspect).join('\n  - ')}
      
      Queries Ran (queries_ran.size):
        - #{queries_ran.map{|l| l.gsub(/\n\s*/, "\n    ")}.join("\n  - ")}
    MSG
  end

  def assert_not_query(*not_expected)
    queries_ran = SQLLogger.log.size
    yield
  ensure
    failed_patterns = []
    queries_ran = SQLLogger.log[queries_ran...]
    
    not_expected.each do |pattern|
      failed_patterns << pattern if queries_ran.any?{ |sql| pattern === sql }
    end

    assert failed_patterns.empty?, <<~MSG
      Unexpected Query pattern(s) found:
        - #{failed_patterns.map(&:inspect).join('\n  - ')}
      
      Queries Ran (queries_ran.size):
        - #{queries_ran.map{|l| l.gsub(/\n\s*/, "\n    ")}.join("\n  - ")}
    MSG
  end
  
  def assert_queries(num = 1, options = {})
    SQLLogger.clear_log
    x = yield
    the_log = ignore_none ? SQLLogger.log_all : SQLLogger.log
    if num == :any
      assert_operator the_log.size, :>=, 1, "1 or more queries expected, but none were executed."
    else
      mesg = "#{the_log.size} instead of #{num} queries were executed.#{the_log.size == 0 ? '' : "\nQueries:\n#{the_log.join("\n")}"}"
      assert_equal num, the_log.size, mesg
    end
    x
  end


  class SQLLogger
    class << self
      attr_accessor :ignored_sql, :log, :log_all
      def clear_log; self.log = []; self.log_all = []; end
    end

    self.clear_log

    self.ignored_sql = [/^PRAGMA/i, /^SELECT currval/i, /^SELECT CAST/i, /^SELECT @@IDENTITY/i, /^SELECT @@ROWCOUNT/i, /^SAVEPOINT/i, /^ROLLBACK TO SAVEPOINT/i, /^RELEASE SAVEPOINT/i, /^SHOW max_identifier_length/i]# , /^BEGIN/i, /^COMMIT/i

    # FIXME: this needs to be refactored so specific database can add their own
    # ignored SQL, or better yet, use a different notification for the queries
    # instead examining the SQL content.
    oracle_ignored     = [/^select .*nextval/i, /^SAVEPOINT/, /^ROLLBACK TO/, /^\s*select .* from all_triggers/im, /^\s*select .* from all_constraints/im, /^\s*select .* from all_tab_cols/im]
    mysql_ignored      = [/^SHOW FULL TABLES/i, /^SHOW FULL FIELDS/, /^SHOW CREATE TABLE /i, /^SHOW VARIABLES /, /^\s*SELECT (?:column_name|table_name)\b.*\bFROM information_schema\.(?:key_column_usage|tables)\b/im]
    postgresql_ignored = [/^\s*select\b.*\bfrom\b.*pg_namespace\b/im, /^\s*select tablename\b.*from pg_tables\b/im, /^\s*select\b.*\battname\b.*\bfrom\b.*\bpg_attribute\b/im, /^SHOW search_path/i]
    sqlite3_ignored =    [/^\s*SELECT name\b.*\bFROM sqlite_master/im, /^\s*SELECT sql\b.*\bFROM sqlite_master/im]

    [oracle_ignored, mysql_ignored, postgresql_ignored, sqlite3_ignored].each do |db_ignored_sql|
      ignored_sql.concat db_ignored_sql
    end

    attr_reader :ignore

    def initialize(ignore = Regexp.union(self.class.ignored_sql))
      @ignore = ignore
    end

    def call(name, start, finish, message_id, values)
      sql = values[:sql]

      # FIXME: this seems bad. we should probably have a better way to indicate
      # the query was cached
      return if 'CACHE' == values[:name]

      self.class.log_all << sql
      unless ignore =~ sql
        if $debugging
        puts caller.select { |l| l.start_with?(File.expand_path('../../lib', __FILE__)) }
        puts "\n\n" 
        end
      end
      self.class.log << sql unless ignore =~ sql
    end
  end
  ActiveSupport::Notifications.subscribe('sql.active_record', SQLLogger.new)

  # test/unit backwards compatibility methods
  alias :assert_raise :assert_raises
  alias :assert_not_empty :refute_empty
  alias :assert_not_equal :refute_equal
  alias :assert_not_in_delta :refute_in_delta
  alias :assert_not_in_epsilon :refute_in_epsilon
  alias :assert_not_includes :refute_includes
  alias :assert_not_instance_of :refute_instance_of
  alias :assert_not_kind_of :refute_kind_of
  alias :assert_no_match :refute_match
  alias :assert_not_nil :refute_nil
  alias :assert_not_operator :refute_operator
  alias :assert_not_predicate :refute_predicate
  alias :assert_not_respond_to :refute_respond_to
  alias :assert_not_same :refute_same
  
end