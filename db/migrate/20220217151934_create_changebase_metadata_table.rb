class CreateChangebaseMetadataTable < ActiveRecord::Migration[6.0]
  
  def up
    table = Rails.application.config.changebase.metadata_table
    
    if !ActiveRecord::Base.connection.table_exists?(table)
      create_table table, id: false do |t|
        t.primary_key :version, :integer
        t.jsonb       :data
      end
    end
  end
  
  def down
    drop_table(Rails.application.config.changebase.metadata_table)
  end
  
end
