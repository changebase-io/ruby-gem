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
    assert_not_query(/INSERT INTO "changebase_metadata"/i) do
      ActiveRecord::Base.with_metadata(nil) do
        @post.destroy
      end
    end
  end

  test 'Base::with_metadata {}' do
    assert_not_query(/INSERT INTO "changebase_metadata"/i) do
      ActiveRecord::Base.with_metadata({}) do
        @post.destroy
      end
    end
  end

  test 'Base::with_metadata DATA' do
    debug do
    ActiveRecord::Base.with_metadata({user: 'tom'}) do
      @post.destroy
    end
  end
    case Changebase.mode
    when 'inline'
      assert_posted('', {
        transaction: {
          lsn: 1,
          timestamp: "2022-05-10T12:04:53.397-04:00",
          metadata: {
            "veniam" => "Corporis repellat ipsam est.",
            "aperiam" => "Odio ut ut et."
          },
          events: [
            { lsn: 6,
              type: "delete",
              schema: "est_rerum_suscipits",
              table: "non_quibusdam_impedits",
              timestamp: "2022-05-10T12:32:14.966-04:00",
              database_id: "85683d67-a51e-4e97-a016-d3666d286789",
              columns: [
                { index: 1,
                  type: "int4",
                  name: "possimus",
                  value: -1608095202,
                }, {
                  index: 2,
                  type: "float4",
                  name: "enim",
                  value: 566881.1375015317,
                }, { index: 3,
                  type: "float4",
                  name: "sequi",
                  value: 216365.3829521479,
                  database_id: "85683d67-a51e-4e97-a016-d3666d286789"
                }, {
                  index: 4,
                  type: "text",
                  name: "iure",
                  value: "Hic soluta sed eius.",
                  database_id: "85683d67-a51e-4e97-a016-d3666d286789"
                }, {
                  index: 5,
                  type: "int2",
                  name: "occaecati",
                  value: -2441,
                  database_id: "85683d67-a51e-4e97-a016-d3666d286789"
                }
              ]
            }
          ]
        }})
    when 'replication'
      assert_query(<<~MSG)
        INSERT INTO "changebase_metadata" ( version, data )
        VALUES ( 1, '{"user":"tom"}' )
        ON CONFLICT ( version )
        DO UPDATE SET version = 1, data = '{"user":"tom"}';
      MSG
    end
  end

  test 'Model::with_metadata nil' do
    assert_not_query(/INSERT INTO "changebase_metadata"/i) do
      Post.with_metadata(nil) do
        @post.destroy
      end
    end
  end

  test 'Model::with_metadata {}' do
    assert_not_query(/INSERT INTO "changebase_metadata"/i) do
      Post.with_metadata({}) do
        @post.destroy
      end
    end
  end

  test 'Model::with_metadata DATA' do
    Post.with_metadata({user: 'tom'}) do
      @post.destroy
    end

    assert_posted('', {}, mode: :inline)

    assert_query(<<~MSG, mode: :replication)
      INSERT INTO "changebase_metadata" ( version, data )
      VALUES ( 1, '{"user":"tom"}' )
      ON CONFLICT ( version )
      DO UPDATE SET version = 1, data = '{"user":"tom"}';
    MSG
  end

end
