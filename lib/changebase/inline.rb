require 'changebase'
Changebase.mode = 'inline'

module Changebase::Inline
  
  def self.load!
    require 'active_record'
    require 'changebase/active_record'

    ::ActiveRecord::Base.include(Changebase::ActiveRecord)
    ::ActiveRecord::ConnectionAdapters::AbstractAdapter.include(Changebase::ActiveRecord::Connection)

    require 'changebase/inline/active_record'
    ::ActiveRecord::Base.include(Changebase::Inline::ActiveRecord)
    
    @loaded = true
  end
  
  def self.loaded?
    @loaded
  end
  
end

Changebase::Inline.load!