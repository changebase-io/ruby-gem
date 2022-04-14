module Changebase
  
  autoload :ActionController, 'changebase/action_controller'
  autoload :Replication, 'changebase/replication'
  
  @config = {
    mode: "replication",
    metadata_table: "changebase_metadata"
  }
  
  def self.metadata_table=(value)
    @config[:metadata_table] = value
  end
  
  def self.metadata_table
    @config[:metadata_table]
  end
  
  def self.mode=(value)
    @config[:mode] = value
  end
  
  def self.mode
    @config[:mode]
  end
  
  def self.connection=(value)
    @config[:connection] = value
  end
  
  def self.connection
    @config[:connection]
  end
  
  def self.configure(**config)
    puts config.inspect
  end
end

require 'changebase/railtie' if defined?(Rails)