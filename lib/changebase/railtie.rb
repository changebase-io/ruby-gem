module AR
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

module ARConnection
    
  def with_metadata(metadata, &block)
    @changebase_metadata = metadata
    puts '!'
    yield
  ensure
    puts '2'
    @changebase_metadata = nil
    # test to ensure cleaned up
  end
  
end


module PSQLConnection

  def execute(sql, name = nil)
    begin_transaction(_lazy: true) if !transaction.open? && write_query?(sql)
    super
  end

  
  def commit_db_transaction
    puts '3'
    if @changebase_metadata && !@changebase_metadata.empty?
      exec_query(ActiveRecord::Base.send(:replace_named_bind_variables, <<~SQL, {version: 1, metadata: ActiveSupport::JSON.encode(@changebase_metadata)}), "CHANGEBASE")
        INSERT INTO changebase_metadata ( version, data )
        VALUES ( :version, :metadata )
        ON CONFLICT ( version )
        DO UPDATE SET version = :version, data = :metadata;
      SQL
    end
    super
  end
    
end
ActiveRecord::Base.include(AR)
ActiveRecord::ConnectionAdapters::AbstractAdapter.include(ARConnection)

require 'active_record/connection_adapters/postgresql_adapter'
ActiveRecord::ConnectionAdapters::PostgreSQLAdapter.include(PSQLConnection)

      
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
