require 'test_helper'

class ActiveRecord::CreateTest < ActiveSupport::TestCase
  
  schema do
    create_table "posts" do |t|
      t.string   "title",            limit: 255
    end

    create_table "changebase_metadata", id: false do |t|
      t.primary_key :version, :integer
      t.jsonb       :data
    end
  end
  
  class Post < ActiveRecord::Base
  end
  
  test 'Base::with_metadata nil' do
    assert_not_query(/INSERT INTO "changebase_metadata"/i) do
      ActiveRecord::Base.with_metadata(nil) do
        Post.create(title: 'first')
      end
    end
  end

  test 'Base::with_metadata {}' do
    assert_not_query(/INSERT INTO "changebase_metadata"/i) do
      ActiveRecord::Base.with_metadata({}) do
        Post.create(title: 'first')
      end
    end
  end

  test 'Base::with_metadata DATA' do
    expected_query = <<~MSG
      INSERT INTO "changebase_metadata" ( version, data )
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
    assert_not_query(/INSERT INTO "changebase_metadata"/i) do
      Post.with_metadata(nil) do
        Post.create(title: 'first')
      end
    end
  end

  test 'Model::with_metadata {}' do
    assert_not_query(/INSERT INTO "changebase_metadata"/i) do
      Post.with_metadata({}) do
        Post.create(title: 'first')
      end
    end
  end

  test 'Model::with_metadata DATA' do
    expected_query = <<~MSG
      INSERT INTO "changebase_metadata" ( version, data )
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


  # Hand written queires
  # --------------------
  
  test 'Model::with_metadata with a write via execute' do
    expected_query = <<~MSG
      INSERT INTO "changebase_metadata" ( version, data )
      VALUES ( 1, '{"user":"tom"}' )
      ON CONFLICT ( version )
      DO UPDATE SET version = 1, data = '{"user":"tom"}';
    MSG
    
    assert_query(expected_query) do
      Post.with_metadata({user: 'tom'}) do
        Post.connection.execute("INSERT INTO posts DEFAULT VALUES")
      end
    end
  end
  
  test 'Model::with_metadata with a write via exec_query' do
    expected_query = <<~MSG
      INSERT INTO "changebase_metadata" ( version, data )
      VALUES ( 1, '{"user":"tom"}' )
      ON CONFLICT ( version )
      DO UPDATE SET version = 1, data = '{"user":"tom"}';
    MSG
    
    assert_query(expected_query) do
      Post.with_metadata({user: 'tom'}) do
        Post.connection.exec_query("INSERT INTO posts DEFAULT VALUES")
      end
    end
  end
  
end