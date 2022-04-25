require 'test_helper'

class ActiveRecordTest < ActiveSupport::TestCase
  
  schema do
    create_table "posts" do |t|
      t.string   "title",            limit: 255
    end

    create_table "x", id: false do |t|
      t.primary_key :version, :integer
      t.jsonb       :data
    end
  end
  
  class Post < ActiveRecord::Base
  end
  
  test 'a custom metadata table', only: :replication do
    Changebase.metadata_table = 'x'

    expected_query = <<~MSG
      INSERT INTO "x" ( version, data )
      VALUES ( 1, '{"user":"tom"}' )
      ON CONFLICT ( version )
      DO UPDATE SET version = 1, data = '{"user":"tom"}';
    MSG

    assert_query(expected_query) do
      ActiveRecord::Base.with_metadata({user: 'tom'}) do
        Post.create(title: 'first')
      end
    end
  ensure
    Changebase.metadata_table = 'changebase_metadata'
  end

  # TODO: test nesting?
  # test 'z' do
  #   ActiveRecord::Base.with_metadata() do
  #     Post.create(title: 'first')
  #     ActiveRecord::Base.transaction do
  #       Post.create(title: 'second')
  #       raise ActiveRecord::Rollback
  #     end
  #   end
  # end
  
end