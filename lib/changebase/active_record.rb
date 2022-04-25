module Changebase::ActiveRecord
  extend ActiveSupport::Concern

  class_methods do
    def with_metadata(metadata, &block)
      connection.with_metadata(metadata, &block)
    end
  end

  def with_metadata(metadata, &block)
    self.class.with_metadata(metadata, &block)
  end

  module Connection
    def with_metadata(metadata, &block)
      @changebase_metadata = metadata
      yield
    ensure
      @changebase_metadata = nil
    end
  end
  
end