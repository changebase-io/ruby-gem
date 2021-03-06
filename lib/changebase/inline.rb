require 'changebase'
Changebase.mode = 'inline'

module Changebase::Inline

  autoload :Event, 'changebase/inline/event'
  autoload :Transaction, 'changebase/inline/transaction'

  def self.load!
    require 'active_record'
    require 'changebase/active_record'

    ::ActiveRecord::Base.include(Changebase::ActiveRecord)
    ::ActiveRecord::ConnectionAdapters::AbstractAdapter.include(Changebase::ActiveRecord::Connection)

    require 'active_record/connection_adapters/postgresql_adapter'
    require 'changebase/inline/active_record'
    ::ActiveRecord::Base.include(Changebase::Inline::ActiveRecord)
    ::ActiveRecord::ConnectionAdapters::PostgreSQLAdapter.include(Changebase::Inline::ActiveRecord::PostgreSQLAdapter)
    ::ActiveRecord::Associations::HasManyThroughAssociation.prepend(Changebase::Inline::Through)
    ::ActiveRecord::Associations::HasManyAssociation.prepend(Changebase::Inline::HasMany)

    @loaded = true
  end

  def self.loaded?
    @loaded
  end

end

Changebase::Inline.load!
