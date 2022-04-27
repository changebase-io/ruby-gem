module Changebase
  
  autoload :Inline, 'changebase/inline'
  autoload :Replication, 'changebase/replication'
  autoload :ActiveRecord, 'changebase/active_record'
  autoload :ActionController, 'changebase/action_controller'
  
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
    @config.merge!(config)
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
    @logger ||= Logger.new(STDOUT)
  end
end

require 'changebase/railtie' if defined?(Rails)



# require 'globalid'
require 'securerandom'
#
# GlobalID::Locator.use :changebase do |gid|
#   Changebase::Event.new({ id: gid.model_id })
# end

class Changebase::Event
  # include GlobalID::Identification

  attr_accessor :id, :metadata, :timestamp, :actions
  
  def initialize(attrs={})
    attrs.each { |k,v| self.send("#{k}=", v) }

    if id
      @persisted = true
    else
      @persisted = false
      @id ||= SecureRandom.uuid
    end

    @actions ||= []
    @timestamp ||= Time.now
    @metadata ||= {}
  end

  def persisted?
    @persisted
  end

  def action!(action)
    action = Changebase::Action.new(action)
    @actions << action
    action
  end
  
  def action_for(type, id, new_options=nil)
    type = type.base_class.model_name.name if !type.is_a?(String)
    action = @actions.find { |a| a.subject_type.to_s == type.to_s && a.subject_id.to_s == id.to_s }
    
    if new_options
      if action
        action.diff.merge!(new_options[:diff]) if new_options.has_key?(:diff)
        action
      else
        action!({ subject_type: type, subject_id: id, type: :update }.merge(new_options))
      end

    else
      action
    end
  end

  def self.create!(attrs={})
    event = self.new(attrs)
    event.save!
    event
  end
    
  def save!
    persisted? ? _update : _create
  end
  
  def _update
    return if actions.empty?
    actions.delete_if { |a| a.diff.empty? }
    payload = JSON.generate({actions: actions.as_json.map{ |json| json[:event_id] = id; json }})
    Changebase.logger.debug("[Changebase] POST /actions WITH #{payload}")
    Changebase.connection.post('/actions', payload)
    @actions = []
  end
  
  def _create
    actions.delete_if { |a| a.diff.empty? }
    payload = JSON.generate(self.as_json)
    Changebase.logger.debug("[Changebase] POST /events WITH #{payload}")
    Changebase.connection.post('/events', payload)
    @actions = []
    @persisted = true
  end

  def as_json
    {
      id:                   id,
      metadata:             metadata,
      timestamp:            timestamp.utc.iso8601(3),
      actions:              actions.as_json
    }
  end

  # def to_gid_param(options={})
  #   to_global_id(options).to_param
  # end
  #
  # def to_global_id(options={})
  #   @global_id ||= GlobalID.create(self, { app: :changebase }.merge(options))
  # end
  #
  # def to_sgid_param(options={})
  #   to_signed_global_id(options).to_param
  # end
  #
  # def to_signed_global_id(options={})
  #    SignedGlobalID.create(self, { app: :changebase }.merge(options))
  # end

end

class Changebase::Action

  attr_accessor :id, :event_id, :type, :timestamp, :subject_type, :subject_id, :diff

  def initialize(attrs)
    attrs.each do |k,v|
      self.send("#{k}=", v)
    end
    self.diff ||= {}
  end
  
  def as_json
    {
      diff:         diff.as_json,
      subject_type: subject_type,
      subject_id:   subject_id,
      timestamp:    timestamp.iso8601(3),
      type:         type,
      event_id:     event_id,
      id:           id
    }.select { |k, v| !v.nil? }
  end

end
