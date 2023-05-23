class CreateChangebaseTables < ActiveRecord::Migration[<%= migration_version %>]

  def change
    create_table :<%= table_name %>, id: false do |t|
      t.primary_key :version, :integer
      t.jsonb       :data
    end
  end

end