module Changebase::ActiveRecord

  autoload :Connection, 'changebase/active_record/connection'
  
  extend ActiveSupport::Concern

  class_methods do
    def with_metadata(metadata, &block)
      connection.with_metadata(metadata, &block)
    end
  end

  def with_metadata(metadata, &block)
    self.class.with_metadata(metadata, &block)
  end
  
  def calculate_identity_digest
    raw_values = Array(self.class.primary_key).map do |attr_name|
      attribute_value_for_digest(attr_name)
    end
    
    Changebase.digest_identity(*raw_values)
  end

  def attribute_value_for_digest(attr_name)
    name = attr_name.to_s
    name = self.class.attribute_aliases[name] || name

    value = attributes_for_database[name]
    type = type_for_attribute(:id)

    case type
    when ActiveRecord::ConnectionAdapters::PostgreSQL::OID::Uuid
      value = value.gsub('-', '')
      [ value.slice(0, 8), value.slice(8, 4), value.slice(12, 4), value.slice(16, 4), value.slice(20, 12) ].join("-")
    else
      value.to_s(:db)
    end
  end
  
end