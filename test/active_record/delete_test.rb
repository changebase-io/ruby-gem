require 'test_helper'

# These test test the ActiveRecord::Persistence#delete method.
#
# Inline mode does not support the ActiveRecord::Persistence#delete method since
# it issues a direct call to the database.
class ActiveRecord::DeleteTest < ActiveSupport::TestCase

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

  setup do
    @post = Post.create!(title: 'one')
  end

  test 'Base::with_metadata nil', only: :replication do
    timestamp = Time.current + 1.day
    travel_to timestamp do
      ActiveRecord::Base.with_metadata(nil) do
        @post.delete
      end
    end

    case Changebase.mode
    when 'replication'
      assert_not_query(/INSERT INTO "changebase_metadata"/i)
    when 'inline'
      assert_not_posted('/transactions', {
        transaction: {
          events: [
            { type: "delete",
              schema: "public",
              table: "posts"
            }
          ]
        }
      })
    end
  end

  test 'Base::with_metadata {}' do
    timestamp = Time.current + 1.day
    travel_to timestamp do
      ActiveRecord::Base.with_metadata({}) do
        @post.delete
      end
    end

    case Changebase.mode
    when 'replication'
      assert_not_query(/INSERT INTO "changebase_metadata"/i)
    when 'inline'
      assert_not_posted('/transactions', {
        transaction: {
          events: [
            { type: "delete",
              schema: "public",
              table: "posts"
            }
          ]
        }
      })
    end
  end

  test 'Base::with_metadata DATA' do
    timestamp = Time.current + 1.day
    travel_to timestamp do
      ActiveRecord::Base.with_metadata({}) do
        @post.delete
      end
    end

    case Changebase.mode
    when 'replication'
      assert_query(<<~SQL)
        INSERT INTO "changebase_metadata" ( version, data )
        VALUES ( 1, '{"user":"tom"}' )
        ON CONFLICT ( version )
        DO UPDATE SET version = 1, data = '{"user":"tom"}';
      SQL
    when 'inline'
      assert_not_posted('/transactions', {
        transaction: {
          events: [
            { type: "delete",
              schema: "public",
              table: "posts"
            }
          ]
        }
      })
    end
  end

  test 'Model::with_metadata nil' do
    timestamp = Time.current + 1.day
    travel_to timestamp do
      Post.with_metadata(nil) do
        @post.delete
      end
    end

    case Changebase.mode
    when 'replication'
      assert_not_query(/INSERT INTO "changebase_metadata"/i)
    when 'inline'
      assert_not_posted('/transactions', {
        transaction: {
          events: [
            { type: "delete",
              schema: "public",
              table: "posts"
            }
          ]
        }
      })
    end
  end

  test 'Model::with_metadata {}' do
    timestamp = Time.current + 1.day
    travel_to timestamp do
      Post.with_metadata({}) do
        @post.delete
      end
    end

    case Changebase.mode
    when 'replication'
      assert_not_query(/INSERT INTO "changebase_metadata"/i)
    when 'inline'
      assert_not_posted('/transactions', {
        transaction: {
          events: [
            { type: "delete",
              schema: "public",
              table: "posts"
            }
          ]
        }
      })
    end
  end

  test 'Model::with_metadata DATA' do
    timestamp = Time.current + 1.day
    travel_to timestamp do
      Post.with_metadata({user: 'tom'}) do
        @post.delete
      end
    end

    case Changebase.mode
    when 'replication'
      assert_query(<<~SQL)
        INSERT INTO "changebase_metadata" ( version, data )
        VALUES ( 1, '{"user":"tom"}' )
        ON CONFLICT ( version )
        DO UPDATE SET version = 1, data = '{"user":"tom"}';
      SQL
    when 'inline'
      assert_not_posted('/transactions', {
        transaction: {
          events: [
            { type: "delete",
              schema: "public",
              table: "posts"
            }
          ]
        }
      })
    end
  end


  # Hand written queires
  # --------------------

  test 'Model::with_metadata with a write via execute' do
    timestamp = Time.current + 1.day
    travel_to timestamp do
      Post.with_metadata({user: 'tom'}) do
        Post.connection.execute("DELETE FROM posts WHERE id = #{@post.id}")
      end
    end

    case Changebase.mode
    when 'replication'
      assert_query(<<~SQL)
        INSERT INTO "changebase_metadata" ( version, data )
        VALUES ( 1, '{"user":"tom"}' )
        ON CONFLICT ( version )
        DO UPDATE SET version = 1, data = '{"user":"tom"}';
      SQL
    when 'inline'
      assert_not_posted('/transactions', {
        transaction: {
          events: [
            { type: "delete",
              schema: "public",
              table: "posts"
            }
          ]
        }
      })
    end
  end

  test 'Model::with_metadata with a write via exec_query' do
    timestamp = Time.current + 1.day
    travel_to timestamp do
      Post.with_metadata({user: 'tom'}) do
        Post.connection.exec_query("DELETE FROM posts WHERE id = #{@post.id}")
      end
    end

    case Changebase.mode
    when 'replication'
      assert_query(<<~SQL)
        INSERT INTO "changebase_metadata" ( version, data )
        VALUES ( 1, '{"user":"tom"}' )
        ON CONFLICT ( version )
        DO UPDATE SET version = 1, data = '{"user":"tom"}';
      SQL
    when 'inline'
      assert_not_posted('/transactions', {
        transaction: {
          events: [
            { type: "delete",
              schema: "public",
              table: "posts"
            }
          ]
        }
      })
    end
  end

end
