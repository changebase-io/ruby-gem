module Changebase

  autoload :VERSION, 'changebase/version'
  autoload :Connection, 'changebase/connection'
  autoload :Inline, 'changebase/inline'
  autoload :Replication, 'changebase/replication'
  autoload :ActiveRecord, 'changebase/active_record'
  autoload :ActionController, 'changebase/action_controller'

  @config = {
    mode: "replication",
    metadata: {
      mode: "message",
      message_prefix: "changebase_metadata",
      table_name: "changebase_metadata"
    }
  }

  def self.mode=(value)
    @config[:mode] = value
  end

  def self.mode
    @config[:mode]
  end

  def self.metadata_mode=(value)
    @config[:metadata][:mode] = value
  end

  def self.metadata_mode
    @config[:metadata][:mode]
  end

  def self.metadata_message_prefix=(value)
    @config[:metadata][:message_prefix] = value
  end

  def self.metadata_message_prefix
    @config[:metadata][:message_prefix]
  end

  def self.metadata_table=(value)
    @config[:metadata][:table_name] = value
  end

  def self.metadata_table
    @config[:metadata][:table_name]
  end

  def self.connection=(value)
    @config[:connection] = value
  end

  def self.connection
    Thread.current[:changebase_connection] ||= Changebase::Connection.new({
      url: @config[:connection]
    })
  end

  def self.configure(**config)
    @config.deep_merge!(config)
    self.logger = @config[:logger] if @config[:logger]
  end

  def self.configured?
    case @config[:mode]
    when 'inline'
      !!@config[:connection]
    else
      true
    end
  end

  def self.logger
    return @logger if defined?(@logger)

    @logger = Logger.new(STDOUT)
  end

  def self.logger=(logger)
    @logger = logger
  end

end

require 'changebase/railtie' if defined?(Rails)
