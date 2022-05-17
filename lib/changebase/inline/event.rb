class Changebase::Inline::Event

  attr_accessor :id, :database_id, :transaction_id, :type, :schema,
    :table, :timestamp, :created_at, :columns

  def initialize(attrs)
    attrs.each do |k,v|
      self.send("#{k}=", v)
    end
    self.columns ||= {}
  end

  def as_json
    {
      id: id,
      transaction_id:     transaction_id,
      lsn:                timestamp.utc.iso8601(3),
      type: type,
      schema: schema,
      table: table,
      timestamp:    timestamp.utc.iso8601(3),
      columns:         columns.as_json,
    }.select { |k, v| !v.nil? }
  end

end
