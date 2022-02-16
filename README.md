# Changebase Ruby Library

The Changebase Ruby library provides convenient access to the Changebase API from
applications written in the Ruby language.

## Installation

```sh
gem install stripe
```

If you are installing via bundler:

```ruby
gem "changebase"
```

## Rails / ActiveRecord Usage

To include metadata when creating or modifying data with ActiveRecord:

```ruby
  ActiveRecord::Base.with_metadata({user: {name: 'Tom'}}) do
    @post.update(title: "A new beging")
  end
```

In a controller you can use the following to log metadata with all updates during
a request:

```ruby
  class ApplicationController < ActionController::Base
    changebase :request_id, -> { request.uuid }
  end
```

The `changebase` function can be called multiple times to include various data.
To nest a value simply give it all the keys.

Below are several diffent way of including metadata:

```ruby
  class ApplicationController < ActionController::Base
    changebase :release, RELEASE_SHA
    changebase :request_id, -> { request.uuid }
    changebase :user, :id, :current_user_id
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

### Configuration

To configure the metadata table that Changebase writes to create a initializer
at `config/initializers/changebase.rb` with the following:

```ruby
Rails.application.config.tap do |config|
  config.changebase.metadata_table = "my_very_cool_custom_metadata_table"
end
```

If you are not using Rails you can configure Changebase directly via:

```ruby
Changebase.metadata_table = "my_very_cool_custom_metadata_table"
```

## Bugs

If you think you found a bug, please file a ticket on the {issue 
tracker}[https://github.com/changebase-io/ruby-gem/issues].