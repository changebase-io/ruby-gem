require 'test_helper'

# These test test the ActiveRecord::Base#destroy method.
class ActiveRecord::DestroyTest < ActiveSupport::TestCase

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

  test "#destroy" do
    timestamp = Time.current + 1.day
    travel_to timestamp do
      ActiveRecord::Base.with_metadata(nil) do
        @post.destroy
      end
    end

    case (Changebase.mode == 'inline' ? 'inline' : "#{Changebase.mode}/#{Changebase.metadata_mode}")
    when 'replication/table'
      assert_not_query(/INSERT INTO "changebase_metadata"/i)
    when 'replication/message'
      assert_not_query(/pg_logical_emit_message/i)
    when 'inline'
      assert_posted('/transactions', {
        transaction: {
          lsn: timestamp.utc.iso8601(3),
          timestamp: timestamp.utc.iso8601(3),
          events: [
            { lsn: timestamp.utc.iso8601(3),
              type: "delete",
              schema: "public",
              table: "posts",
              timestamp: timestamp.utc.iso8601(3),
              columns: [
                { index: 0,
                  identity: true,
                  type: "bigint",
                  name: "id",
                  value: nil,
                  previous_value: @post.id,
                }, {
                  index: 1,
                  identity: false,
                  type: "character varying(255)",
                  name: "title",
                  value: nil,
                  previous_value: "one"
                }
              ]
            }
          ]
        }
      })
    end
  end

  test 'Base::with_metadata nil' do
    timestamp = Time.current + 1.day
    travel_to timestamp do
      ActiveRecord::Base.with_metadata(nil) do
        @post.destroy
      end
    end

    case (Changebase.mode == 'inline' ? 'inline' : "#{Changebase.mode}/#{Changebase.metadata_mode}")
    when 'replication/table'
      assert_not_query(/INSERT INTO "changebase_metadata"/i)
    when 'replication/message'
      assert_not_query(/pg_logical_emit_message/i)
    when 'inline'
      assert_posted('/transactions', {
          transaction: {
            lsn: timestamp.utc.iso8601(3),
            timestamp: timestamp.utc.iso8601(3),
            events: [
              { lsn: timestamp.utc.iso8601(3),
                type: "delete",
                schema: "public",
                table: "posts",
                timestamp: timestamp.utc.iso8601(3),
                columns: [
                  { index: 0,
                    identity: true,
                    type: "bigint",
                    name: "id",
                    value: nil,
                    previous_value: @post.id,
                  }, {
                    index: 1,
                    identity: false,
                    type: "character varying(255)",
                    name: "title",
                    value: nil,
                    previous_value: "one"
                  }
                ]
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
        @post.destroy
      end
    end

    case (Changebase.mode == 'inline' ? 'inline' : "#{Changebase.mode}/#{Changebase.metadata_mode}")
    when 'replication/table'
      assert_not_query(/INSERT INTO "changebase_metadata"/i)
    when 'replication/message'
      assert_not_query(/pg_logical_emit_message/i)
    when 'inline'
      assert_posted('/transactions', {
        transaction: {
          lsn: timestamp.utc.iso8601(3),
          timestamp: timestamp.utc.iso8601(3),
          events: [
            { lsn: timestamp.utc.iso8601(3),
              type: "delete",
              schema: "public",
              table: "posts",
              timestamp: timestamp.utc.iso8601(3),
              columns: [
                { index: 0,
                  identity: true,
                  type: "bigint",
                  name: "id",
                  value: nil,
                  previous_value: @post.id,
                }, {
                  index: 1,
                  identity: false,
                  type: "character varying(255)",
                  name: "title",
                  value: nil,
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
        @post.destroy
      end
    end

    case (Changebase.mode == 'inline' ? 'inline' : "#{Changebase.mode}/#{Changebase.metadata_mode}")
    when 'replication/table'
      assert_query(<<~MSG)
        INSERT INTO "changebase_metadata" ( version, data )
        VALUES ( 1, '{"user":"tom"}' )
        ON CONFLICT ( version )
        DO UPDATE SET version = 1, data = '{"user":"tom"}';
      MSG
    when 'replication/message'
      assert_query(<<~MSG)
        SELECT pg_logical_emit_message(true, 'changebase_metadata', '{"user":"tom"}');
      MSG
    when 'inline'
      assert_posted('/transactions', {
        transaction: {
          lsn: timestamp.utc.iso8601(3),
          timestamp: timestamp.utc.iso8601(3),
          metadata: { user: "tom" },
          events: [
            { lsn: timestamp.utc.iso8601(3),
              type: "delete",
              schema: "public",
              table: "posts",
              timestamp: timestamp.utc.iso8601(3),
              columns: [
                { index: 0,
                    identity: true,
                    type: "bigint",
                    name: "id",
                    value: nil,
                    previous_value: @post.id,
                  }, {
                    index: 1,
                    identity: false,
                    type: "character varying(255)",
                    name: "title",
                    value: nil,
                    previous_value: "one"
                  }
              ]
            }
          ]
        }})
    end
  end

  test 'Model::with_metadata nil' do
    timestamp = Time.current + 1.day
    travel_to timestamp do
      Post.with_metadata(nil) do
        @post.destroy
      end
    end

    case (Changebase.mode == 'inline' ? 'inline' : "#{Changebase.mode}/#{Changebase.metadata_mode}")
    when 'replication/table'
      assert_not_query(/INSERT INTO "changebase_metadata"/i)
    when 'replication/message'
      assert_not_query(/pg_logical_emit_message/i)
    when 'inline'
      assert_posted('/transactions', {
        transaction: {
          lsn: timestamp.utc.iso8601(3),
          timestamp: timestamp.utc.iso8601(3),
          events: [
            { lsn: timestamp.utc.iso8601(3),
              type: "delete",
              schema: "public",
              table: "posts",
              timestamp: timestamp.utc.iso8601(3),
              columns: [
                { index: 0,
                    identity: true,
                    type: "bigint",
                    name: "id",
                    value: nil,
                    previous_value: @post.id,
                  }, {
                    index: 1,
                    identity: false,
                    type: "character varying(255)",
                    name: "title",
                    value: nil,
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
        @post.destroy
      end
    end

    case (Changebase.mode == 'inline' ? 'inline' : "#{Changebase.mode}/#{Changebase.metadata_mode}")
    when 'replication/table'
      assert_not_query(/INSERT INTO "changebase_metadata"/i)
    when 'replication/message'
      assert_not_query(/pg_logical_emit_message/i)
    when 'inline'
      assert_posted('/transactions', {
        transaction: {
          lsn: timestamp.utc.iso8601(3),
          timestamp: timestamp.utc.iso8601(3),
          events: [
            { lsn: timestamp.utc.iso8601(3),
              type: "delete",
              schema: "public",
              table: "posts",
              timestamp: timestamp.utc.iso8601(3),
              columns: [
                { index: 0,
                    identity: true,
                    type: "bigint",
                    name: "id",
                    value: nil,
                    previous_value: @post.id,
                  }, {
                    index: 1,
                    identity: false,
                    type: "character varying(255)",
                    name: "title",
                    value: nil,
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
        @post.destroy
      end
    end

    case (Changebase.mode == 'inline' ? 'inline' : "#{Changebase.mode}/#{Changebase.metadata_mode}")
    when 'replication/table'
      assert_query(<<~MSG)
        INSERT INTO "changebase_metadata" ( version, data )
        VALUES ( 1, '{"user":"tom"}' )
        ON CONFLICT ( version )
        DO UPDATE SET version = 1, data = '{"user":"tom"}';
      MSG
    when 'replication/message'
      assert_query(<<~MSG)
        SELECT pg_logical_emit_message(true, 'changebase_metadata', '{"user":"tom"}');
      MSG
    when 'inline'
      assert_posted('/transactions', {
        transaction: {
          lsn: timestamp.utc.iso8601(3),
          timestamp: timestamp.utc.iso8601(3),
          metadata: { user: "tom" },
          events: [
            { lsn: timestamp.utc.iso8601(3),
              type: "delete",
              schema: "public",
              table: "posts",
              timestamp: timestamp.utc.iso8601(3),
              columns: [
                { index: 0,
                    identity: true,
                    type: "bigint",
                    name: "id",
                    value: nil,
                    previous_value: @post.id,
                  }, {
                    index: 1,
                    identity: false,
                    type: "character varying(255)",
                    name: "title",
                    value: nil,
                    previous_value: "one"
                  }
              ]
            }
          ]
        }})
    end
  end

end
