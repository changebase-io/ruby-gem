require 'test_helper'

class ActiveRecordTest < ActiveSupport::TestCase
  
  schema do
    create_table "posts" do |t|
      t.string   "title",            limit: 255
    end

    create_table "photos", force: :cascade do |t|
      t.integer  "post_id"
    end
    
    create_table "changebase_metadata", id: false do |t|
      t.primary_key :version, :integer
      t.jsonb       :data
    end
        
  end
  
  class Post < ActiveRecord::Base
    has_many :photos
  end

  class Photo < ActiveRecord::Base
    belongs_to :posts
  end
  
  test 'Base::with_metadata nil' do
    assert_not_query(/INSERT INTO changebase_metadata/i) do
      ActiveRecord::Base.with_metadata(nil) do
        Post.create(title: 'first')
      end
    end
  end

  test 'Base::with_metadata {}' do
    assert_not_query(/INSERT INTO changebase_metadata/i) do
      ActiveRecord::Base.with_metadata({}) do
        Post.create(title: 'first')
      end
    end
  end

  test 'Base::with_metadata DATA' do
    expected_query = <<~MSG
      INSERT INTO changebase_metadata ( version, data )
      VALUES ( 1, '{"user":"tom"}' )
      ON CONFLICT ( version )
      DO UPDATE SET version = 1, data = '{"user":"tom"}';
    MSG

    assert_query(expected_query) do
      ActiveRecord::Base.with_metadata({user: 'tom'}) do
        Post.create(title: 'first')
      end
    end
  end



  test 'Model::with_metadata nil' do
    assert_not_query(/INSERT INTO changebase_metadata/i) do
      Post.with_metadata(nil) do
        Post.create(title: 'first')
      end
    end
  end

  test 'Model::with_metadata {}' do
    assert_not_query(/INSERT INTO changebase_metadata/i) do
      Post.with_metadata({}) do
        Post.create(title: 'first')
      end
    end
  end

  test 'Model::with_metadata DATA' do
    expected_query = <<~MSG
      INSERT INTO changebase_metadata ( version, data )
      VALUES ( 1, '{"user":"tom"}' )
      ON CONFLICT ( version )
      DO UPDATE SET version = 1, data = '{"user":"tom"}';
    MSG

    assert_query(expected_query) do
      Post.with_metadata({user: 'tom'}) do
        Post.create(title: 'first')
      end
    end
  end


  test 'Model::with_metadata with a read' do
    assert_not_query(/INSERT INTO changebase_metadata/i) do
      Post.with_metadata({user: 'tom'}) do
        Post.first
      end
    end
  end

  # execute
  # exec_query
  # exec_update
  # exec_delete
  # exec_insert
  
  test 'Model::with_metadata with a read via exec' do
    assert_not_query(/INSERT INTO changebase_metadata/i) do
      debug do
      Post.with_metadata({user: 'tom'}) do
        Post.connection.execute("INSERT INTO photos DEFAULT VALUES")
      end
    end
      end
  end
  
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