module Changebase
  autoload :ActiveRecord, 'changebase/active_record'
  autoload :ActionController, 'changebase/action_controller'
  
  @metadata_table = "changebase_metadata"
  
  def self.metadata_table=(value)
    @metadata_table = value
  end
  
  def self.metadata_table
    @metadata_table
  end
end

require 'changebase/railtie' if defined?(Rails)