require 'test_helper'

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

  test 'Base::with_metadata nil' do
    ActiveRecord::Base.with_metadata(nil) do
      @post.destroy
    end

    case Changebase.mode
    when 'replication'
      assert_not_query(/INSERT INTO "changebase_metadata"/i)
    when 'inline'
      assert_posted('/transactions', {
          transaction: {
            lsn: 1,
            timestamp: "2022-05-10T12:04:53.397-04:00",
            events: [
              { lsn: 6,
                type: "delete",
                schema: "public",
                table: "posts",
                timestamp: "2022-05-10T12:32:14.966-04:00",
                columns: [
                  { index: 0,
                    type: "bigint",
                    name: "id",
                    value: nil,
                    previous_value: 1,
                  }, {
                    index: 1,
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

  # test 'Base::with_metadata {}' do
  #   ActiveRecord::Base.with_metadata({}) do
  #     @post.destroy
  #   end

  #   case Changebase.mode
  #   when 'replication'
  #     assert_not_query(/INSERT INTO "changebase_metadata"/i)
  #   when 'inline'
  #     assert_posted('', {
  #       transaction: {
  #         lsn: 1,
  #         timestamp: "2022-05-10T12:04:53.397-04:00",
  #         metadata: {},
  #         events: [
  #           { lsn: 6,
  #             type: "delete",
  #             schema: "public",
  #             table: "posts",
  #             timestamp: "2022-05-10T12:32:14.966-04:00",
  #             columns: [
  #               { index: 1,
  #                 type: "int4",
  #                 name: "id",
  #                 value: 1,
  #               }, {
  #                 index: 2,
  #                 type: "text",
  #                 name: "title",
  #                 value: "one",
  #               }
  #             ]
  #           }
  #         ]
  #       }})
  #   end
  # end

  # test 'Base::with_metadata DATA' do
  #   ActiveRecord::Base.with_metadata({user: 'tom'}) do
  #     @post.destroy
  #   end

  #   case Changebase.mode
  #   when 'inline'
  #     assert_posted('', {
  #       transaction: {
  #         lsn: 1,
  #         timestamp: "2022-05-10T12:04:53.397-04:00",
  #         metadata: { user: "tom" },
  #         events: [
  #           { lsn: 6,
  #             type: "delete",
  #             schema: "public",
  #             table: "posts",
  #             timestamp: "2022-05-10T12:32:14.966-04:00",
  #             columns: [
  #               { index: 1,
  #                 type: "int4",
  #                 name: "id",
  #                 value: 1,
  #               }, {
  #                 index: 2,
  #                 type: "text",
  #                 name: "title",
  #                 value: "one",
  #               }
  #             ]
  #           }
  #         ]
  #       }})
  #   when 'replication'
  #     assert_query(<<~MSG)
  #       INSERT INTO "changebase_metadata" ( version, data )
  #       VALUES ( 1, '{"user":"tom"}' )
  #       ON CONFLICT ( version )
  #       DO UPDATE SET version = 1, data = '{"user":"tom"}';
  #     MSG
  #   end
  # end

  # test 'Model::with_metadata nil' do
  #   Post.with_metadata(nil) do
  #     @post.destroy
  #   end

  #   case Changebase.mode
  #   when 'replication'
  #     assert_not_query(/INSERT INTO "changebase_metadata"/i)
  #   when 'inline'
  #     assert_posted('', {
  #       transaction: {
  #         lsn: 1,
  #         timestamp: "2022-05-10T12:04:53.397-04:00",
  #         events: [
  #           { lsn: 6,
  #             type: "delete",
  #             schema: "public",
  #             table: "posts",
  #             timestamp: "2022-05-10T12:32:14.966-04:00",
  #             columns: [
  #               { index: 1,
  #                 type: "int4",
  #                 name: "id",
  #                 value: 1,
  #               }, {
  #                 index: 2,
  #                 type: "text",
  #                 name: "title",
  #                 value: "one",
  #               }
  #             ]
  #           }
  #         ]
  #       }})
  #   end
  # end

  # test 'Model::with_metadata {}' do
  #   Post.with_metadata({}) do
  #     @post.destroy
  #   end

  #   case Changebase.mode
  #   when 'replication'
  #     assert_not_query(/INSERT INTO "changebase_metadata"/i)
  #   when 'inline'
  #     assert_posted('', {
  #       transaction: {
  #         lsn: 1,
  #         timestamp: "2022-05-10T12:04:53.397-04:00",
  #         metadata: {},
  #         events: [
  #           { lsn: 6,
  #             type: "delete",
  #             schema: "public",
  #             table: "posts",
  #             timestamp: "2022-05-10T12:32:14.966-04:00",
  #             columns: [
  #               { index: 1,
  #                 type: "int4",
  #                 name: "id",
  #                 value: 1,
  #               }, {
  #                 index: 2,
  #                 type: "text",
  #                 name: "title",
  #                 value: "one",
  #               }
  #             ]
  #           }
  #         ]
  #       }})
  #   end
  # end

  # test 'Model::with_metadata DATA' do
  #   Post.with_metadata({user: 'tom'}) do
  #     @post.destroy
  #   end

  #   case Changebase.mode
  #   when 'replication'
  #     assert_query(<<~MSG, mode: :replication)
  #       INSERT INTO "changebase_metadata" ( version, data )
  #       VALUES ( 1, '{"user":"tom"}' )
  #       ON CONFLICT ( version )
  #       DO UPDATE SET version = 1, data = '{"user":"tom"}';
  #     MSG
  #   when 'inline'
  #     assert_posted('', {
  #       transaction: {
  #         lsn: 1,
  #         timestamp: "2022-05-10T12:04:53.397-04:00",
  #         metadata: { user: "tom" },
  #         events: [
  #           { lsn: 6,
  #             type: "delete",
  #             schema: "public",
  #             table: "posts",
  #             timestamp: "2022-05-10T12:32:14.966-04:00",
  #             columns: [
  #               { index: 1,
  #                 type: "int4",
  #                 name: "id",
  #                 value: 1,
  #               }, {
  #                 index: 2,
  #                 type: "text",
  #                 name: "title",
  #                 value: "one",
  #               }
  #             ]
  #           }
  #         ]
  #       }})
  #   end
  # end

end
