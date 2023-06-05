class Changebase::Transaction < Changebase::Record
  self.table_name = "transactions"
  
  enum type: { insert: 0, update: 1, delete: 2, truncate: 3 }, _suffix: true

  alias_attribute :table_name, :table
  
  belongs_to :integration
  
  has_many :events, foreign_key: :transaction_id
  has_many :metadata do
    def to_h
      Metadatum.to_h(proxy_association.load_target)
    end
  end

  
end