# AcceptsNestedAttributesForPublicId

<a href="https://badge.fury.io/rb/accepts_nested_attributes_for_public_id" target="_blank"><img height="21" style='border:0px;height:21px;' border='0' src="https://badge.fury.io/rb/accepts_nested_attributes_for_public_id.svg" alt="Gem Version"></a>
<a href='https://github.com/westonganger/accepts_nested_attributes_for_public_id/actions' target='_blank'><img src="https://github.com/westonganger/accepts_nested_attributes_for_public_id/workflows/Tests/badge.svg" style="max-width:100%;" height='21' style='border:0px;height:21px;' border='0' alt="CI Status"></a>
<a href='https://rubygems.org/gems/accepts_nested_attributes_for_public_id' target='_blank'><img height='21' style='border:0px;height:21px;' src='https://img.shields.io/gem/dt/accepts_nested_attributes_for_public_id?color=brightgreen&label=Rubygems%20Downloads' border='0' alt='RubyGems Downloads' /></a>

A patch for Rails to support using a public ID column instead of ID for use with `accepts_nested_attributes_for`

Supports Rails 5, 6, 7+

Why:

- By default ActiveRecord and `accepts_nested_attributes_for` does not respect `to_param` or provide any ability to utilize a public ID column. This results in your DB primary keys being exposed in your forms.
- This was [extracted from a PR to Rails core](https://github.com/rails/rails/pull/48390) until this functionality is otherwise achievable in Rails core proper.

# Installation

```ruby
gem 'accepts_nested_attributes_for_public_id'
```

# Usage

You now have access to the following options:

### Option A: Define a accepts_nested_attributes_for_public_id_column method on your class

```ruby
class Post < ApplicationRecord
  has_many :comments
  accepts_nested_attributes_for :comments
end

class Comment < ApplicationRecord
  belongs_to :post

  def self.accepts_nested_attributes_for_public_id_column
    :my_public_id_db_column
  end
end
```

### Option B: Use the :public_id_column option on accepts_nested_attributes_for

```ruby
class Post < ApplicationRecord
  has_many :comments
  accepts_nested_attributes_for :comments, public_id_column: :my_public_id_db_column
end

class Comment < ApplicationRecord
  belongs_to :post
end
```

# How is this safe

The code for Nested Attributes in Rails core has not changed since around Rails 4 (Rails 7.0 is the current release at the time of writing this)

Because this patch requires changes in the very middle of some larger sized methods we are unable to use `super` in the patches. This can make it fragile if new changes were introduced to Rails core.

We have taken steps to ensure that no issues are caused by any future Rails changes by adding [runtime contracts](./lib/accepts_nested_attributes_for_public_id/method_contracts.rb) that ensure the original method source matches our saved contract of the current sources of these methods. If a new Rails version were to change the original method source then you would receive a runtime error stating that we are unable to apply the patch until the gem has been made compatible with any changed code.

# Testing

```
RAILS_ENV=test bundle exec rake db:create
RAILS_ENV=test bundle exec rake db:migrate
bundle exec rspec
```

We can locally test different versions of Rails using `ENV['RAILS_VERSION']` and different database gems using `ENV['DB_GEM']`

```
export RAILS_VERSION=7.0
bundle install
bundle exec rspec
```

# Credits

Created & Maintained by [Weston Ganger](https://westonganger.com) - [@westonganger](https://github.com/westonganger)
