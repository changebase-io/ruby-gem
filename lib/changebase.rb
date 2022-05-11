module Changebase

  autoload :VERSION, 'changebase/version'
  autoload :Connection, 'changebase/connection'
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
    Thread.current[:changebase_connection] ||= Changebase::Connection.new({
      url: @config[:connection]
    })
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
require 'securerandom'

module Changebase

  class Transaction

    attr_accessor :id, :metadata, :timestamp, :events

    def initialize(attrs={})
      attrs.each { |k,v| self.send("#{k}=", v) }

      if id
        @persisted = true
      else
        @persisted = false
        @id ||= SecureRandom.uuid
      end

      @events ||= []
      @timestamp ||= Time.now
      @metadata ||= {}
    end

    def persisted?
      @persisted
    end

    def event!(event)
      event = Changebase::Event.new(event)
      @events << event
      event
    end

    def event_for(table_name, id, new_options=nil)
      # type = type.base_class.model_name.name if !type.is_a?(String)
      # event = @events.find { |a| a.subject_type.to_s == type.to_s && a.subject_id.to_s == id.to_s }

      # if new_options
      #   if event
      #     event.diff.merge!(new_options[:diff]) if new_options.has_key?(:diff)
      #     event
      #   else
          event!({ subject_type: type, subject_id: id, type: :update }.merge(new_options))
      #   end

      # else
      #   event
      # end
    end

    def self.create!(attrs={})
      transaction = self.new(attrs)
      transaction.save!
      transaction
    end

    def save!
      persisted? ? _update : _create
    end

    def _update
      return if events.empty?
      events.delete_if { |a| a.diff.empty? }
      payload = JSON.generate({events: events.as_json.map{ |json| json[:transaction_id] = id; json }})
      Changebase.logger.debug("[Changebase] POST /events WITH #{payload}")
      Changebase.connection.post('/events', payload)
      @events = []
    end

    def _create
      events.delete_if { |a| a.diff.empty? }
      payload = JSON.generate(self.as_json)
      Changebase.logger.debug("[Changebase] POST /transactions WITH #{payload}")
      Changebase.connection.post('/transactions', payload)
      @events = []
      @persisted = true
    end

    def as_json
      {
        id:                   id,
        # TODO: Add lsn
        timestamp:            timestamp.utc.iso8601(3),
        metadata:             metadata,
        events:               events.as_json
      }
    end

  end

  class Event

    attr_accessor :id, :transaction_id, :type, :timestamp, :subject_type, :subject_id, :columns

    def initialize(attrs)
      attrs.each do |k,v|
        self.send("#{k}=", v)
      end
      self.columns ||= {}
    end

    def as_json
      # TODO: diff -> columns
      #       Add schema, lsn
      {
        diff:         diff.as_json,
        subject_type: subject_type,
        subject_id:   subject_id,
        timestamp:    timestamp.iso8601(3),
        type:         type,
        transaction_id:     transaction_id,
        id:           id
      }.select { |k, v| !v.nil? }
    end

  end
end
