module Changebase::ActiveRecord
  extend ActiveSupport::Concern
  
  module ClassMethods
    def with_metadata(metadata, &block)
      connection.with_metadata(metadata, &block)
    end
  end
  
  def with_metadata(metadata, &block)
    self.class.with_metadata(metadata, &block)
  end
end


module Changebase::ActiveRecord::Connection

  def with_metadata(metadata, &block)
    @changebase_metadata = metadata
    yield
  ensure
    @changebase_metadata = nil
  end
  
end

module Changebase::ActiveRecord::PostgreSQLAdapter

  def without_changebase
    @without_changebase = true
    yield
  ensure
    @without_changebase = false
  end
  
  def drop_database(name) # :nodoc:
    without_changebase { super }
  end

  def drop_table(table_name, **options) # :nodoc:
    without_changebase { super }
  end

  def create_database(name, options = {})
    without_changebase { super }
  end
  
  def recreate_database(name, options = {}) # :nodoc:
    without_changebase { super }
  end
  
  def execute(sql, name = nil)
    if !@without_changebase && !current_transaction.open? && write_query?(sql)
      transaction { super }
    else
      super
    end
  end
  
  def exec_query(sql, name = "SQL", binds = [], prepare: false)
    if !@without_changebase && !current_transaction.open? && write_query?(sql)
      transaction { super }
    else
      super
    end
  end
  
  def exec_delete(sql, name = nil, binds = []) # :nodoc:
    if !@without_changebase && !current_transaction.open? && write_query?(sql)
      transaction { super }
    else
      super
    end
  end

  def commit_db_transaction
    if !@without_changebase && @changebase_metadata && !@changebase_metadata.empty?
      sql = ActiveRecord::Base.send(:replace_named_bind_variables, <<~SQL, {version: 1, metadata: ActiveSupport::JSON.encode(@changebase_metadata)})
        INSERT INTO changebase_metadata ( version, data )
        VALUES ( :version, :metadata )
        ON CONFLICT ( version )
        DO UPDATE SET version = :version, data = :metadata;
      SQL
      
      log(sql, "CHANGEBASE") do
        ActiveSupport::Dependencies.interlock.permit_concurrent_loads do
          @connection.async_exec(sql)
        end
      end
    end
    super
  end
  
end


ActiveRecord::Base.include(Changebase::ActiveRecord)
ActiveRecord::ConnectionAdapters::AbstractAdapter.include(Changebase::ActiveRecord::Connection)

require 'active_record/connection_adapters/postgresql_adapter'
ActiveRecord::ConnectionAdapters::PostgreSQLAdapter.include(Changebase::ActiveRecord::PostgreSQLAdapter)

      
# module Rails
#   class Application
#
#     attr_accessor :changebase
#
#   end
# end
#
# class Changebase::Railtie < Rails::Railtie
#
#   config.changebase = ActiveSupport::OrderedOptions.new
#
#   config.changebase.metadata_table = "changebase_metadata"
#
#   def initialize_configs(app)
#     config = app.config.changebase
#
#     if seekrets = app.credentials[:changebase] || app.secrets[:changebase]
#       config.metadata_table = seekrets[:metadata_table] if seekrets[:metadata_table]
#     end
#     # ignored_relations
#
#     # if !config.logger
#     #   config.logger = Rails.logger
#     #   config.server.logger = Rails.logger if config.server
#     # end
#   end
#
#   config.after_initialize do |app|
#     initialize_configs(app)
#     config = app.config.bob_ross
#
#     # BobRoss.configure(config.except(:server))
#
#     # if config.server
#     #   require 'bob_ross/server'
#     #   app.bob_ross_server = BobRoss::Server.new(config.server.except(:prefix))
#     #   app.routes.prepend do
#     #     mount app.bob_ross_server => config.server.prefix
#     #   end
#     # end
#   end
#
# end
