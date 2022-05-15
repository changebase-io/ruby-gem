require 'test_helper'

class HasAndBelongsToManyTest < ActiveSupport::TestCase

  schema do
    create_table "posts" do |t|
      t.string   "title",            limit: 255
    end

    create_table "topics" do |t|
      t.string   "name",             limit: 255
    end

    create_join_table :posts, :topics do |t|
    end
  end

  class Post < ActiveRecord::Base
    has_and_belongs_to_many :topics
  end

  class Topic < ActiveRecord::Base
    has_and_belongs_to_many :posts
  end

  test '::create with existing has_and_belongs_to_many association', only: :inline do
    timestamp = Time.current + 1.day
    topic = Topic.create(name: "Known Unkowns")
    post = travel_to(timestamp) do
      Post.create(title: "Black Holes", topics: [topic])
    end


    assert_posted('/transactions', {
      transaction: {
        lsn: timestamp.utc.iso8601(3),
        timestamp: timestamp.utc.iso8601(3),
        events: [
          {
            lsn: timestamp.utc.iso8601(3),
            type: "insert",
            schema: "public",
            table: "posts",
            timestamp: timestamp.utc.iso8601(3),
            columns: [
              { index: 0,
                identity: true,
                type: "bigint",
                name: "id",
                value: post.id,
                previous_value: nil
              }, {
                index: 1,
                identity: false,
                type: "character varying(255)",
                name: "title",
                value: "Black Holes",
                previous_value: nil
              }
            ]
          }, {
            lsn: timestamp.utc.iso8601(3),
            type: "insert",
            schema: "public",
            table: "posts_topics",
            timestamp: timestamp.utc.iso8601(3),
            columns: [
              {
                index: 0,
                identity: true,
                type: "bigint",
                name: "post_id",
                value: post.id,
                previous_value: nil
              }, {
                index: 1,
                identity: true,
                type: "bigint",
                name: "topic_id",
                value: topic.id,
                previous_value: nil
              }
            ]
          }
        ]
      }
    })
  end

  test '::create with new has_and_belongs_to_many association' do
    timestamp = Time.current + 1.day
    topic, post = travel_to(timestamp) do
      topic = Topic.new(name: "Known Unkowns")
      post = Post.create(title: "Black Holes", topics: [topic])
      [ topic, post ]
    end

    assert_posted("/transactions", {
      transaction: {
        lsn: timestamp.utc.iso8601(3),
        timestamp: timestamp.utc.iso8601(3),
        events: [
          {
            lsn: timestamp.utc.iso8601(3),
            type: "insert",
            schema: "public",
            table: "posts",
            timestamp: timestamp.utc.iso8601(3),
            columns: [
              { index: 0,
                identity: true,
                name: "id",
                type: "bigint",
                value: post.id,
                previous_value: nil
              }, {
                index: 1,
                identity: false,
                name: "title",
                type: "character varying(255)",
                value: "Black Holes",
                previous_value: nil
              }
            ]
          }, {
            lsn: timestamp.utc.iso8601(3),
            type: "insert",
            schema: "public",
            table: "topics",
            timestamp: timestamp.utc.iso8601(3),
            columns: [
              {
                index: 0,
                identity: true,
                name: "id",
                type: "bigint",
                value: topic.id,
                previous_value: nil
              }, {
                index: 1,
                identity: false,
                name: "name",
                type: "character varying(255)",
                value: "Known Unkowns",
                previous_value: nil
              }
            ]
          }, {
            lsn: timestamp.utc.iso8601(3),
            type: "insert",
            schema: "public",
            table: "posts_topics",
            timestamp: timestamp.utc.iso8601(3),
            columns: [
              {
                index: 0,
                identity: true,
                name: "post_id",
                type: "bigint",
                value: post.id,
                previous_value: nil
              }, {
                index: 1,
                identity: true,
                name: "topic_id",
                type: "bigint",
                value: topic.id,
                previous_value: nil
              }
            ]
          }
        ]
      }
    })
  end

  test '::update with adding existing has_and_belongs_to_many association' do
    timestamp = Time.current + 1.day
    topic = Topic.create(name: "Known Unkowns")
    post = Post.create(title: "Black Holes", topics: [])

    travel_to(timestamp) do
      post.update(topics: [topic])
    end

    assert_posted("/transactions", {
      transaction: {
        lsn: timestamp.utc.iso8601(3),
        timestamp: timestamp.utc.iso8601(3),
        events: [
          {
            lsn: timestamp.utc.iso8601(3),
            type: "insert",
            schema: "public",
            table: "posts_topics",
            timestamp: timestamp.utc.iso8601(3),
            columns: [
              {
                index: 0,
                identity: true,
                name: "post_id",
                type: "bigint",
                value: post.id,
                previous_value: nil
              }, {
                index: 1,
                identity: true,
                name: "topic_id",
                type: "bigint",
                value: topic.id,
                previous_value: nil
              }
            ]
          }
        ]
      }
    })
  end

  # test '::update with adding new has_and_belongs_to_many association' do
  #   @region = create(:region)
  #   WebMock::RequestRegistry.instance.reset!
  #
  #   travel_to(@time) { @region.update(properties: [build(:property)]) }
  #   @property = @region.properties.first
  #
  #   assert_posted("/events") do
  #     assert_action_for @property, {
  #       timestamp: @time.iso8601(3),
  #       type: 'create',
  #       subject_type: "Property",
  #       subject_id: @property.id,
  #       diff: {
  #         id: [nil, @property.id],
  #         name: [nil, @property.name],
  #         description: [nil, @property.description],
  #         constructed: [nil, @property.constructed],
  #         size: [nil, @property.size],
  #         created_at: [nil, @property.created_at],
  #         aliases: [nil, []],
  #         active: [nil, @property.active],
  #         region_ids: [[], [@region.id]]
  #       }
  #     }
  #
  #     assert_action_for @region, {
  #       diff: {
  #         property_ids: [[], [@property.id]]
  #       },
  #       subject_type: "Region",
  #       subject_id: @region.id,
  #       timestamp: @time.iso8601(3),
  #       type: 'update'
  #     }
  #   end
  # end
  #
  # test '::update with removing has_and_belongs_to_many association' do
  #   @property = create(:property)
  #   @region = create(:region, properties: [@property])
  #   WebMock::RequestRegistry.instance.reset!
  #
  #   travel_to(@time) { @region.update(properties: []) }
  #
  #   assert_posted("/events") do
  #     assert_action_for @region, {
  #       diff: {
  #         property_ids: [[@property.id], []]
  #       },
  #       subject_type: "Region",
  #       subject_id: @region.id,
  #       timestamp: @time.iso8601(3),
  #       type: 'update'
  #     }
  #
  #     assert_action_for @property, {
  #       timestamp: @time.iso8601(3),
  #       type: 'update',
  #       subject_type: "Property",
  #       subject_id: @property.id,
  #       diff: {
  #         region_ids: [[@region.id], []]
  #       }
  #     }
  #   end
  # end
  #
  # test '::update with replacing has_and_belongs_to_many association' do
  #   @property1 = create(:property)
  #   @property2 = create(:property)
  #   @region = create(:region, properties: [@property1])
  #   WebMock::RequestRegistry.instance.reset!
  #
  #   travel_to(@time) { @region.update(properties: [@property2]) }
  #
  #   assert_posted("/events") do
  #     assert_action_for @region, {
  #       diff: {
  #         property_ids: [[@property1.id], [@property2.id]]
  #       },
  #       subject_type: "Region",
  #       subject_id: @region.id,
  #       timestamp: @time.iso8601(3),
  #       type: 'update'
  #     }
  #
  #     assert_action_for @property1, {
  #       timestamp: @time.iso8601(3),
  #       type: 'update',
  #       subject_type: "Property",
  #       subject_id: @property1.id,
  #       diff: {
  #         region_ids: [[@region.id], []]
  #       }
  #     }
  #
  #     assert_action_for @property2, {
  #       timestamp: @time.iso8601(3),
  #       type: 'update',
  #       subject_type: "Property",
  #       subject_id: @property2.id,
  #       diff: {
  #         region_ids: [[], [@region.id]]
  #       }
  #     }
  #   end
  # end
  #
  # test '::destroying updates has_and_belongs_to_many associations' do
  #   @property = create(:property)
  #   @region = create(:region, properties: [@property])
  #   WebMock::RequestRegistry.instance.reset!
  #
  #   travel_to(@time) { @region.destroy }
  #
  #   assert_posted("/events") do
  #     assert_action_for @region, {
  #       diff: {
  #         id: [@region.id, nil],
  #         name: [@region.name, nil],
  #         property_ids: [[@property.id], []]
  #       },
  #       subject_type: "Region",
  #       subject_id: @region.id,
  #       timestamp: @time.iso8601(3),
  #       type: 'destroy'
  #     }.as_json
  #
  #     assert_action_for @property, {
  #       timestamp: @time.iso8601(3),
  #       type: 'update',
  #       subject_type: "Property",
  #       subject_id: @property.id,
  #       diff: {
  #         region_ids: [[@region.id], []]
  #       }
  #     }.as_json
  #   end
  # end
  #
  # test 'has_and_belongs_to_many <<'
  # test 'has_and_belongs_to_many.delete'
  # test 'has_and_belongs_to_many.destroy'
  # test 'has_and_belongs_to_many='
  #
  # test 'has_and_belongs_to_many with different class name' do
  #   @photo = create(:photo)
  #   @property = create(:property)
  #   WebMock::RequestRegistry.instance.reset!
  #
  #   travel_to(@time) { @property.update(attachments: [@photo]) }
  #
  #   assert_posted("/events") do
  #     assert_action_for @property, {
  #       diff: {
  #         attachment_ids: [[], [@photo.id]]
  #       },
  #       subject_type: "Property",
  #       subject_id: @property.id,
  #       timestamp: @time.iso8601(3),
  #       type: 'update'
  #     }
  #   end
  #
  # end
  #
  #
  # test 'has_and_belongs_to_many_ids=' do
  #   @parent = create(:region)
  #   @child = create(:region)
  #   WebMock::RequestRegistry.instance.reset!
  #
  #   travel_to(@time) { @child.parent_ids = [@parent.id] }
  #
  #   assert_posted("/events") do
  #     assert_action_for @child, {
  #       diff: {
  #         parent_ids: [[], [@parent.id]]
  #       },
  #       subject_type: "Region",
  #       subject_id: @child.id,
  #       timestamp: @time.iso8601(3),
  #       type: 'update'
  #     }.as_json
  #
  #     assert_action_for @parent, {
  #       timestamp: @time.iso8601(3),
  #       type: 'update',
  #       subject_type: "Region",
  #       subject_id: @parent.id,
  #       diff: {
  #         child_ids: [[], [@child.id]]
  #       }
  #     }.as_json
  #   end
  # end
  #
  # test 'has_and_belongs_to_many.clear'
  # test 'has_and_belongs_to_many.create'

end
