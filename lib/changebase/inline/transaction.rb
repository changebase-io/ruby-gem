require 'securerandom'

class Changebase::Inline::Transaction

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
    event = Changebase::Inline::Event.new(event)
    @events << event
    event
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
    events.delete_if { |a| a.columns.empty? }
    payload = JSON.generate({transaction: self.as_json})
    Changebase.logger.debug("[Changebase] POST /transactions WITH #{payload}")
    Changebase.connection.post('/transactions', payload)
    @events = []
    @persisted = true
  end

  def as_json
    result = {
      id:                   id,
      lsn:                  timestamp.utc.iso8601(3),
      timestamp:            timestamp.utc.iso8601(3),
      events:               events.as_json
    }
    result[:metadata] = metadata.as_json if !metadata.empty?
    result
  end

end