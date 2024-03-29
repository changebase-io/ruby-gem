# Changebase Ruby Library

The Changebase Ruby library provides convenient access to the Changebase API from
applications written in the Ruby language.

## Installation

```sh
gem install changebase
```

If you are installing via bundler:

```ruby
gem "changebase"
```

### ActionController

In a controller you can use the following to log metadata with all updates during
a request:

```ruby
  class ApplicationController < ActionController::Base
    changebase do
      {
        request_id: request.uuid,
        user: {
          id: current_user.id
        }
      }
    end
  end
```

The `changebase` function can be called multiple times to include various data.
To nest a value simply give it all the keys so it knows where to bury the value.

Below are several diffent way of including metadata:

```ruby
  class ApplicationController < ActionController::Base

    # Just a block returning a hash of metadata.
    changebase do
        { my: data }
    end

    # Sets `release` in the metadata to the string RELEASE_SHA
    changebase :release, RELEASE_SHA

    # Sets `request_id` in the metadata to the value returned from the `Proc`
    changebase :request_id, -> { request.uuid }

    # Sets `user.id` in the metadata to the value returned from the
    # `current_user_id` function
    changebase :user, :id, :current_user_id

    # Sets `user.name` in the metadata to the value returned from the block
    changebase :user, :name do
      current_user.name
    end

    def current_user_id
      current_user.id
    end
  end
```

In the above example the following would be logged with all database changes:

```ruby
{
  release:     'd5db29cd03a2ed055086cef9c31c252b4587d6d0',
  request_id:  'a39073a5-10b9-41b7-b5f0-06806853507b',
  user: {
    id:        'f06114cc-7819-4906-85dc-b93edb0fb08c',
    name:      'Tom'
  }
}
```

### ActiveRecord

To include metadata when creating or modifying data with ActiveRecord:

```ruby
  ActiveRecord::Base.with_metadata({user: {name: 'Tom'}}) do
    @post.update(title: "A new beging")
  end
```

### Configuration

#### Replication Mode

The default mode for the `changebase` gem is `replication`. In this mode
Changebase is setup to replicate your database and record events via the
replication stream.

The default configuration in `replication` mode is to emit the metadata
as messages, this requires no configuration. If this does not work you can
configure `metadata_mode` to be `"table"`. In `table` mode `changebase`
will write metadata to the `"changebase_metadata"` table.

To configure the metadata table create an initializer at
`config/initializers/changebase.rb`:

```ruby
Rails.application.config.tap do |config|
  # Defaults:
  # config.changebase.metadata_mode = "message"
  # config.changebase.metadata_message_prefix = "changebase_metadata"
  config.changebase.metadata_mode = "table"
  config.changebase.metadata_table = "cool_custom_metadata_table"
end
```

If you are not using Rails you can configure Changebase directly via:

```ruby
Changebase.metadata_mode = "table"
Changebase.metadata_table = "cool_custom_metadata_table"

Or

Changebase.configure(metadata_mode: "table", metadata_table: "cool_custom_metadata_table")
```

#### Inline Mode

If you are unable to setup database replication you can use inline mode. Events
will be sent to through the Changebase API. You will collect roughly the same
information, but potentionally to miss events and changes in your database
if you are not careful, or if another application accesses the database directly.

##### Limitations

- Any changes made to the database by ActiveRecord that does not first
  instantiate the records will not be caputred. These methods include:
  - [ActiveRecord::ConnectionAdapters::DatabaseStatements#execute](https://api.rubyonrails.org/classes/ActiveRecord/ConnectionAdapters/DatabaseStatements.html#method-i-execute)
  - [ActiveRecord::ConnectionAdapters::DatabaseStatements#exec_query](https://api.rubyonrails.org/classes/ActiveRecord/ConnectionAdapters/DatabaseStatements.html#method-i-exec_query)
  - [ActiveRecord::ConnectionAdapters::DatabaseStatements#exec_update](https://api.rubyonrails.org/classes/ActiveRecord/ConnectionAdapters/DatabaseStatements.html#method-i-exec_update)
  - [ActiveRecord::ConnectionAdapters::DatabaseStatements#exec_insert](https://api.rubyonrails.org/classes/ActiveRecord/ConnectionAdapters/DatabaseStatements.html#method-i-exec_insert)
  - [ActiveRecord::ConnectionAdapters::DatabaseStatements#exec_delete](https://api.rubyonrails.org/classes/ActiveRecord/ConnectionAdapters/DatabaseStatements.html#method-i-exec_delete)
  - [ActiveRecord::Persistence#delete](https://api.rubyonrails.org/classes/ActiveRecord/Persistence.html#method-i-delete)
  - [ActiveRecord::Persistence#update_column](https://api.rubyonrails.org/classes/ActiveRecord/Persistence.html#method-i-update_column)
  - [ActiveRecord::Persistence#update_columns](https://api.rubyonrails.org/classes/ActiveRecord/Persistence.html#method-i-update_columns)
  - [ActiveRecord::Relation#touch_all](https://api.rubyonrails.org/classes/ActiveRecord/Relation.html#method-i-touch_all)
  - [ActiveRecord::Relation#update_all](https://api.rubyonrails.org/classes/ActiveRecord/Relation.html#method-i-update_all)
  - [ActiveRecord::Relation#delete_all](https://api.rubyonrails.org/classes/ActiveRecord/Relation.html#method-i-delete_all)
  - [ActiveRecord::Relation#delete_by](https://api.rubyonrails.org/classes/ActiveRecord/Relation.html#method-i-delete_by)
- Any changes made to the database outside of the Rails application will not be
  captured.
- Ordering of events will not be guaranteed. The timestamp will be used as the
  LSN, which may not be in the same order of transactions / events in the database.

To configure Changebase in the `"inline"` mode create a initializer at
`config/initializers/changebase.rb` with the following:

```ruby
Rails.application.config.tap do |config|
  config.changebase.mode = "inline"
  config.changebase.connection = "https://#{ ENV.fetch('CHANGEBASE_API_KEY') }@changebase.io"
end
```

If you are not using Rails you can configure Changebase directly via:

```ruby
Changebase.configure do |changebase|
  changebase.mode = "inline"
  changebase.connection = "https://#{ ENV.fetch('CHANGEBASE_API_KEY') }@changebase.io"
end

# Or

Changebase.configure(
    mode: "inline",
    connection: "https://API_KEY@chanbase.io"
)
```

## Bugs

If you think you found a bug, please file a ticket on the [issue
tracker](https://github.com/changebase-io/ruby-gem/issues).
