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
    reset!
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
            table: "posts_topics",
            timestamp: timestamp.utc.iso8601(3),
            columns: [
              {
                index: 0,
                type: "bigint",
                name: "post_id",
                value: post.id,
                previous_value: nil,
                identity: true
              }, {
                index: 1,
                type: "bigint",
                name: "topic_id",
                value: topic.id,
                previous_value: nil,
                identity: true
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
    reset!

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

  test '::update with replacing has_and_belongs_to_many association with new' do
    timestamp = Time.current + 1.day
    topic = Topic.create(name: "Known Unkowns")
    post = Post.create(title: "Black Holes", topics: [topic])
    reset!

    new_topic = travel_to(timestamp) do
      new_topic = Topic.new(name: "Known Knowns")
      post.update(topics: [new_topic])
      new_topic
    end

    assert_posted("/transactions", {
      transaction: {
        lsn: timestamp.utc.iso8601(3),
        timestamp: timestamp.utc.iso8601(3),
        events: [
          {
            lsn: timestamp.utc.iso8601(3),
            type: "delete",
            schema: "public",
            table: "posts_topics",
            timestamp: timestamp.utc.iso8601(3),
            columns: [
              {
                index: 0,
                identity: true,
                name: "post_id",
                type: "bigint",
                value: nil,
                previous_value: post.id
              }, {
                index: 1,
                identity: true,
                name: "topic_id",
                type: "bigint",
                value: nil,
                previous_value: topic.id
              }
            ]
          },
          {
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
                value: new_topic.id,
                previous_value:nil
              }, {
                index: 1,
                identity: false,
                name: "name",
                type: "character varying(255)",
                value: "Known Knowns",
                previous_value: nil
              }
            ]
          },
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
                value: new_topic.id,
                previous_value: nil
              }
            ]
          }
        ]
      }
    })
  end

  test '::update with removing has_and_belongs_to_many association' do
    timestamp = Time.current + 1.day
    topic = Topic.create(name: "Known Unkowns")
    post = Post.create(title: "Black Holes", topics: [topic])
    reset!

    travel_to(timestamp) do
      post.update(topics: [])
    end

    assert_posted("/transactions", {
      transaction: {
        lsn: timestamp.utc.iso8601(3),
        timestamp: timestamp.utc.iso8601(3),
        events: [
          {
            lsn: timestamp.utc.iso8601(3),
            type: "delete",
            schema: "public",
            table: "posts_topics",
            timestamp: timestamp.utc.iso8601(3),
            columns: [
              {
                index: 0,
                identity: true,
                name: "post_id",
                type: "bigint",
                value: nil,
                previous_value: post.id
              }, {
                index: 1,
                identity: true,
                name: "topic_id",
                type: "bigint",
                value: nil,
                previous_value: topic.id
              }
            ]
          }
        ]
      }
    })
  end

  test '::update with replacing has_and_belongs_to_many association' do
    timestamp = Time.current + 1.day
    topic1 = Topic.create(name: "Known Unknowns")
    topic2 = Topic.create(name: "Known Knowns")
    post = Post.create(title: "Black Holes", topics: [topic1])
    reset!

    travel_to(timestamp) do
      post.update(topics: [topic2])
    end

    assert_posted("/transactions", {
      transaction: {
        lsn: timestamp.utc.iso8601(3),
        timestamp: timestamp.utc.iso8601(3),
        events: [
          {
            lsn: timestamp.utc.iso8601(3),
            type: "delete",
            schema: "public",
            table: "posts_topics",
            timestamp: timestamp.utc.iso8601(3),
            columns: [
              {
                index: 0,
                identity: true,
                name: "post_id",
                type: "bigint",
                value: nil,
                previous_value: post.id
              }, {
                index: 1,
                identity: true,
                name: "topic_id",
                type: "bigint",
                value: nil,
                previous_value: topic1.id
              }
            ]
          },
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
                value: topic2.id,
                previous_value: nil
              }
            ]
          }
        ]
      }
    })
  end

  test '::destroying updates has_and_belongs_to_many associations' do
    timestamp = Time.current + 1.day
    topic = Topic.create(name: "Known Unknowns")
    post = Post.create(title: "Black Holes", topics: [topic])
    reset!

    travel_to(timestamp) do
      post.destroy
    end

    assert_posted("/transactions", {
      transaction: {
        lsn: timestamp.utc.iso8601(3),
        timestamp: timestamp.utc.iso8601(3),
        events: [
          {
            lsn: timestamp.utc.iso8601(3),
            type: "delete",
            schema: "public",
            table: "posts_topics",
            timestamp: timestamp.utc.iso8601(3),
            columns: [
              {
                index: 0,
                identity: true,
                name: "post_id",
                type: "bigint",
                value: nil,
                previous_value: post.id
              }, {
                index: 1,
                identity: true,
                name: "topic_id",
                type: "bigint",
                value: nil,
                previous_value: topic.id
              }
            ]
          },
          {
            lsn: timestamp.utc.iso8601(3),
            type: "delete",
            schema: "public",
            table: "posts",
            timestamp: timestamp.utc.iso8601(3),
            columns: [
              {
                index: 0,
                identity: true,
                name: "id",
                type: "bigint",
                value: nil,
                previous_value: post.id
              }, {
                index: 1,
                identity: false,
                name: "title",
                type: "character varying(255)",
                value: nil,
                previous_value: "Black Holes"
              }
            ]
          }
        ]
      }
    })
  end

  test 'has_and_belongs_to_many <<' do
    timestamp = Time.current + 1.day
    topic = Topic.create(name: "Known Unkowns")
    post = Post.create(title: "Black Holes", topics: [])

    travel_to(timestamp) do
      post.topics << topic
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
            table: "posts_topics",
            timestamp: timestamp.utc.iso8601(3),
            columns: [
              {
                index: 0,
                type: "bigint",
                name: "post_id",
                value: post.id,
                previous_value: nil,
                identity: true
              }, {
                index: 1,
                type: "bigint",
                name: "topic_id",
                value: topic.id,
                previous_value: nil,
                identity: true
              }
            ]
          }
        ]
      }
    })
  end

  test 'has_and_belongs_to_many.delete' do
    timestamp = Time.current + 1.day
    topic = Topic.create(name: "Known Unknowns")
    post = Post.create(title: "Black Holes", topics: [ topic ])

    travel_to(timestamp) do
      post.topics.delete(topic)
    end

    assert_posted("/transactions", {
      transaction: {
        lsn: timestamp.utc.iso8601(3),
        timestamp: timestamp.utc.iso8601(3),
        events: [
          {
            lsn: timestamp.utc.iso8601(3),
            type: "delete",
            schema: "public",
            table: "posts_topics",
            timestamp: timestamp.utc.iso8601(3),
            columns: [
              {
                index: 0,
                identity: true,
                name: "post_id",
                type: "bigint",
                value: nil,
                previous_value: post.id
              }, {
                index: 1,
                identity: true,
                name: "topic_id",
                type: "bigint",
                value: nil,
                previous_value: topic.id
              }
            ]
          }
        ]
      }
    })
  end

  test 'has_and_belongs_to_many.destroy' do
    timestamp = Time.current + 1.day
    topic = Topic.create(name: "Known Unknowns")
    post = Post.create(title: "Black Holes", topics: [ topic ])

    travel_to(timestamp) do
      # debug do
      post.topics.destroy(topic)
      # end
    end

    assert_posted("/transactions", {
      transaction: {
        lsn: timestamp.utc.iso8601(3),
        timestamp: timestamp.utc.iso8601(3),
        events: [
          {
            lsn: timestamp.utc.iso8601(3),
            type: "delete",
            schema: "public",
            table: "posts_topics",
            timestamp: timestamp.utc.iso8601(3),
            columns: [
              {
                index: 0,
                identity: true,
                name: "post_id",
                type: "bigint",
                value: nil,
                previous_value: post.id
              }, {
                index: 1,
                identity: true,
                name: "topic_id",
                type: "bigint",
                value: nil,
                previous_value: topic.id
              }
            ]
          }
        ]
      }
    })
  end

  test 'has_and_belongs_to_many=' do
    timestamp = Time.current + 1.day
    topic = Topic.create(name: "Known Unknowns")
    post = Post.create(title: "Black Holes")
    reset!

    travel_to(timestamp) do
      post.topics = [ topic ]
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

  test 'has_and_belongs_to_many_ids=' do
    timestamp = Time.current + 1.day
    topic = Topic.create(name: "Known Unknowns")
    post = Post.create(title: "Black Holes")
    reset!

    travel_to(timestamp) do
      post.topic_ids = [topic.id]
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

  # test 'has_and_belongs_to_many.clear' do
  #   timestamp = Time.current + 1.day
  #   topic = Topic.create(name: "Known Unknowns")
  #   post = Post.create(title: "Black Holes", topics: [ topic ])

  #   travel_to(timestamp) do
  #     post.topics.clear
  #   end

  #   assert_posted("/transactions", {
  #     transaction: {
  #       lsn: timestamp.utc.iso8601(3),
  #       timestamp: timestamp.utc.iso8601(3),
  #       events: [
  #         {
  #           lsn: timestamp.utc.iso8601(3),
  #           type: "delete",
  #           schema: "public",
  #           table: "posts_topics",
  #           timestamp: timestamp.utc.iso8601(3),
  #           columns: [
  #             {
  #               index: 0,
  #               identity: true,
  #               name: "post_id",
  #               type: "bigint",
  #               value: nil,
  #               previous_value: post.id
  #             }, {
  #               index: 1,
  #               identity: true,
  #               name: "topic_id",
  #               type: "bigint",
  #               value: nil,
  #               previous_value: topic.id
  #             }
  #           ]
  #         }
  #       ]
  #     }
  #   })
  # end

  test 'has_and_belongs_to_many.create' do
    timestamp = Time.current + 1.day
    post = Post.create(title: "Black Holes")

    topic = travel_to(timestamp) do
      post.topics.create(name: "Known Unknowns")
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
            table: "topics",
            timestamp: timestamp.utc.iso8601(3),
            columns: [
              { index: 0,
                identity: true,
                type: "bigint",
                name: "id",
                value: topic.id,
                previous_value: nil
              }, {
                index: 1,
                identity: false,
                name: "name",
                type: "character varying(255)",
                value: "Known Unknowns",
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

end
