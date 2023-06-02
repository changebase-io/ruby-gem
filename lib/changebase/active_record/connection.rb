module Changebase::ActiveRecord::Connection
  
  def with_metadata(metadata, &block)
    @changebase_metadata = metadata
    yield
  ensure
    @changebase_metadata = nil
  end
  
end