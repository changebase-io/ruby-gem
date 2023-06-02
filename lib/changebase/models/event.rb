class Changebase::Event < Changebase::Record
  self.table_name = "events"
  self.inheritance_column = nil
  
  enum type: { insert: 0, update: 1, delete: 2, truncate: 3 }, _suffix: true

  alias_attribute :table_name, :table
  
  belongs_to :integration
  belongs_to :transaxtion, class_name: "Changebase::Transaction", foreign_key: :transaction_id
  has_many :columns, -> () { order(:index) }
  # has_many :metadata, through: :transaxtion
  has_many :metadata,
    foreign_key: :transaction_id,
    primary_key: :transaction_id \
  do
    def to_h
      Array(proxy_association.load_target).map do |m|
        [ m.name, m.value ]
      end.to_h
    end
  end

  
end