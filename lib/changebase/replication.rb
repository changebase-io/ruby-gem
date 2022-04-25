require 'changebase'
Changebase.mode = 'replication'

module Changebase::Replication
  def self.load!
    require 'active_record'

    ::ActiveRecord::Base.include(Changebase::ActiveRecord)
    ::ActiveRecord::ConnectionAdapters::AbstractAdapter.include(Changebase::ActiveRecord::Connection)
    
    require 'active_record/connection_adapters/postgresql_adapter'
    require 'changebase/replication/active_record'
    ::ActiveRecord::ConnectionAdapters::PostgreSQLAdapter.include(Changebase::Replication::ActiveRecord::PostgreSQLAdapter)
    
    @loaded = true
  end
  
  def self.loaded?
    @loaded
  end
  
end

Changebase::Replication.load!