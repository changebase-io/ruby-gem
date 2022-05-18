require 'test_helper'

class ActiveRecord::UpdateTest < ActiveSupport::TestCase

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

  test "updating primary key", only: :inline do
    timestamp = Time.current + 1.day
    next_id = @post.class.connection.execute('SELECT nextval(\'posts_id_seq\')')[0]['nextval']
    previous_id = @post.id
    travel_to timestamp do
      ActiveRecord::Base.with_metadata(nil) do
        @post.update(id: next_id)
      end
    end

    assert_posted('/transactions', {
      transaction: {
        lsn: timestamp.utc.iso8601(3),
        timestamp: timestamp.utc.iso8601(3),
        events: [
          { lsn: timestamp.utc.iso8601(3),
            type: "update",
            schema: "public",
            table: "posts",
            timestamp: timestamp.utc.iso8601(3),
            columns: [
              { index: 0,
                identity: true,
                type: "bigint",
                name: "id",
                value: next_id,
                previous_value: previous_id
              }, {
                index: 1,
                identity: false,
                type: "character varying(255)",
                name: "title",
                value: "one",
                previous_value: "one"
              }
            ]
          }
        ]
      }})
  end

  test 'Base::with_metadata nil' do
    timestamp = Time.current + 1.day
    travel_to timestamp do
      ActiveRecord::Base.with_metadata(nil) do
        @post.update(title: 'two')
      end
    end

    case Changebase.mode
    when 'replication'
      assert_not_query(/INSERT INTO "changebase_metadata"/i)
    when 'inline'
      assert_posted('/transactions', {
        transaction: {
          lsn: timestamp.utc.iso8601(3),
          timestamp: timestamp.utc.iso8601(3),
          events: [
            { lsn: timestamp.utc.iso8601(3),
              type: "update",
              schema: "public",
              table: "posts",
              timestamp: timestamp.utc.iso8601(3),
              columns: [
                { index: 0,
                  identity: true,
                  type: "bigint",
                  name: "id",
                  value: @post.id,
                  previous_value: @post.id
                }, {
                  index: 1,
                  identity: false,
                  type: "character varying(255)",
                  name: "title",
                  value: "two",
                  previous_value: "one"
                }
              ]
            }
          ]
        }})
    end
  end

  test 'Base::with_metadata {}' do
    timestamp = Time.current + 1.day
    travel_to timestamp do
      ActiveRecord::Base.with_metadata({}) do
        @post.update(title: 'two')
      end
    end

    case Changebase.mode
    when 'replication'
      assert_not_query(/INSERT INTO "changebase_metadata"/i)
    when 'inline'
      assert_posted('/transactions', {
        transaction: {
          lsn: timestamp.utc.iso8601(3),
          timestamp: timestamp.utc.iso8601(3),
          events: [
            { lsn: timestamp.utc.iso8601(3),
              type: "update",
              schema: "public",
              table: "posts",
              timestamp: timestamp.utc.iso8601(3),
              columns: [
                { index: 0,
                  identity: true,
                  type: "bigint",
                  name: "id",
                  value: @post.id,
                  previous_value: @post.id
                }, {
                  index: 1,
                  identity: false,
                  type: "character varying(255)",
                  name: "title",
                  value: "two",
                  previous_value: "one"
                }
              ]
            }
          ]
        }})
    end
  end

  test 'Base::with_metadata DATA' do
    timestamp = Time.current + 1.day
    travel_to timestamp do
      ActiveRecord::Base.with_metadata({user: 'tom'}) do
        @post.update(title: 'two')
      end
    end

    case Changebase.mode
    when 'inline'
      assert_posted('/transactions', {
        transaction: {
          lsn: timestamp.utc.iso8601(3),
          timestamp: timestamp.utc.iso8601(3),
          metadata: { user: "tom" },
          events: [
            { lsn: timestamp.utc.iso8601(3),
              type: "update",
              schema: "public",
              table: "posts",
              timestamp: timestamp.utc.iso8601(3),
              columns: [
                { index: 0,
                  identity: true,
                  type: "bigint",
                  name: "id",
                  value: @post.id,
                  previous_value: @post.id
                }, {
                  index: 1,
                  identity: false,
                  type: "character varying(255)",
                  name: "title",
                  value: "two",
                  previous_value: "one"
                }
              ]
            }
          ]
        }})
    when 'replication'
      assert_query(<<~SQL)
        INSERT INTO "changebase_metadata" ( version, data )
        VALUES ( 1, '{"user":"tom"}' )
        ON CONFLICT ( version )
        DO UPDATE SET version = 1, data = '{"user":"tom"}';
      SQL
    end
  end

  test 'Model::with_metadata nil' do
    timestamp = Time.current + 1.day
    travel_to timestamp do
      Post.with_metadata(nil) do
        @post.update(title: 'two')
      end
    end

    case Changebase.mode
    when 'replication'
      assert_not_query(/INSERT INTO "changebase_metadata"/i)
    when 'inline'
      assert_posted('/transactions', {
        transaction: {
          lsn: timestamp.utc.iso8601(3),
          timestamp: timestamp.utc.iso8601(3),
          events: [
            { lsn: timestamp.utc.iso8601(3),
              type: "update",
              schema: "public",
              table: "posts",
              timestamp: timestamp.utc.iso8601(3),
              columns: [
                { index: 0,
                  identity: true,
                  type: "bigint",
                  name: "id",
                  value: @post.id,
                  previous_value: @post.id
                }, {
                  index: 1,
                  identity: false,
                  type: "character varying(255)",
                  name: "title",
                  value: "two",
                  previous_value: "one"
                }
              ]
            }
          ]
        }})
    end
  end

  test 'Model::with_metadata {}' do
    timestamp = Time.current + 1.day
    travel_to timestamp do
      Post.with_metadata({}) do
        @post.update(title: 'two')
      end
    end

    case Changebase.mode
    when 'replication'
      assert_not_query(/INSERT INTO "changebase_metadata"/i)
    when 'inline'
      assert_posted('/transactions', {
        transaction: {
          lsn: timestamp.utc.iso8601(3),
          timestamp: timestamp.utc.iso8601(3),
          events: [
            { lsn: timestamp.utc.iso8601(3),
              type: "update",
              schema: "public",
              table: "posts",
              timestamp: timestamp.utc.iso8601(3),
              columns: [
                { index: 0,
                  identity: true,
                  name: "id",
                  type: "bigint",
                  value: @post.id,
                  previous_value: @post.id
                }, {
                  index: 1,
                  identity: false,
                  name: "title",
                  type: "character varying(255)",
                  value: "two",
                  previous_value: "one"
                }
              ]
            }
          ]
        }})
    end
  end

  test 'Model::with_metadata DATA' do
    timestamp = Time.current + 1.day
    travel_to timestamp do
      Post.with_metadata({user: 'tom'}) do
        @post.update(title: 'two')
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
      assert_posted('/transactions', {
        transaction: {
          lsn: timestamp.utc.iso8601(3),
          timestamp: timestamp.utc.iso8601(3),
          metadata: { user: "tom" },
          events: [
            { lsn: timestamp.utc.iso8601(3),
              type: "update",
              schema: "public",
              table: "posts",
              timestamp: timestamp.utc.iso8601(3),
              columns: [
                { index: 0,
                  identity: true,
                  type: "bigint",
                  name: "id",
                  value: @post.id,
                  previous_value: @post.id
                }, {
                  index: 1,
                  identity: false,
                  type: "character varying(255)",
                  name: "title",
                  value: "two",
                  previous_value: "one"
                }
              ]
            }
          ]
        }})
    end
  end


  # Hand written queires
  # --------------------

  test 'Model::with_metadata with a write via execute', only: :replication do
    timestamp = Time.current + 1.day
    travel_to timestamp do
      Post.with_metadata({user: 'tom'}) do
        Post.connection.execute("UPDATE posts SET title = 'two' WHERE id = #{ @post.id }")
      end
    end

    assert_query(<<~SQL)
      INSERT INTO "changebase_metadata" ( version, data )
      VALUES ( 1, '{"user":"tom"}' )
      ON CONFLICT ( version )
      DO UPDATE SET version = 1, data = '{"user":"tom"}';
    SQL
  end

  test 'Model::with_metadata with a write via exec_query', only: :replication  do
    timestamp = Time.current + 1.day
    travel_to timestamp do
      Post.with_metadata({user: 'tom'}) do
        Post.connection.exec_query("UPDATE posts SET title = 'two' WHERE id = #{ @post.id }")
      end
    end

    assert_query(<<~SQL)
      INSERT INTO "changebase_metadata" ( version, data )
      VALUES ( 1, '{"user":"tom"}' )
      ON CONFLICT ( version )
      DO UPDATE SET version = 1, data = '{"user":"tom"}';
    SQL
  end

end
