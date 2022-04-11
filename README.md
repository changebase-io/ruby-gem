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

## Rails

Once you install the Gem run your migration to autmatically create the metadata
table for your database by runing:

`rails db:migrate`

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

The default model for the `changebase` gem is `replication`. In this mode
Changebase is setup to replicate your database and record events via the
replication stream.

By default without any configuration `changebase` will write metadata to the
`"changebase_metadata"`. To configure the metadata table that Changebase writes
to create a initializer at `config/initializers/changebase.rb` with the following:

```ruby
Rails.application.config.tap do |config|
  config.changebase.metadata_table = "my_very_cool_custom_metadata_table"
end
```

If you are not using Rails you can configure Changebase directly via:

```ruby
Changebase.metadata_table = "my_very_cool_custom_metadata_table"
```

#### API/Sync Mode

In the event you cannot setup your database to replicate to changebase you can
use the synchronous API mode. Events will be sent to Changebase over our HTTP API.
This mode will enable you collect roughly the same information but has the
potentional to miss events and changes in your database if you are not careful.

To configure Changebase in the `"api/sync"` mode create a initializer at
`config/initializers/changebase.rb` with the following:

```ruby
Rails.application.config.tap do |config|
  config.changebase.mode = "api/sync"
  config.changebase.connection = "https://API_KEY@chanbase.io"
end
```

If you are not using Rails you can configure Changebase directly via:

```ruby
Changebase.configure do |config|
  config.changebase.mode = "api/sync"
  config.changebase.connection = "https://API_KEY@chanbase.io"
end
```

## Bugs

If you think you found a bug, please file a ticket on the [issue 
tracker](https://github.com/changebase-io/ruby-gem/issues).
