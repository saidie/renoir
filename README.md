# Renoir

[![Gem Version](https://badge.fury.io/rb/renoir.svg)](https://badge.fury.io/rb/renoir)
[![Build Status](https://travis-ci.org/saidie/renoir.svg?branch=master)](https://travis-ci.org/saidie/renoir)

A production ready Redis cluster client for Ruby.

Renoir provides compatible interface with [redis-rb](https://github.com/redis/redis-rb/).

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'renoir'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install renoir

## Usage

You can request to a Redis cluster by instantiating `Renoir::Client` with `cluster_nodes` option.

```ruby
require 'renoir'

rc = Renoir::Client.new(cluster_nodes: ['127.0.0.1:30001'])

puts rc.set('hoge', 123) #=> OK
puts rc.set('fuga', 456) #=> OK
puts rc.get('hoge') #=> 123
puts rc.get('fuga') #=> 456
```

Options for [redis-rb](https://github.com/redis/redis-rb/) could also be passed as an argument:

```ruby
rc = Renoir::Client.new(
  cluster_nodes: ['127.0.0.1:30001'],

  # redis-rb options
  timeout: 100,
  password: 'password',
  driver: :hiredis
)
```

### Dispatch command to nodes directly

Renoir dispatches a command only if a slot is determined by the command. This also includes no-keys commands like `KEYS`, `BGSAVE` and so on.

If you would like to dispatch such commands, `Renoir::Client#each_node` could be used:

```ruby
keys = []
rc.each_node do |node|
  keys += node.keys('test_*')
end
p keys
```

## Configuration

Following options could be passed to `Renoir::Client#new`:

### `cluster_nodes` (required)

`Array` of cluster node locations. At least one location must be specified.

A location could be `String`, `Array` or `Hash`:

```ruby
cluster_nodes: [
  '127.0.0.1:30001',
  ['127.0.0.1', 30002],
  { host: 127.0.0.1, port: 30003 }
]
```

### `max_redirection`

Max number of redirections. Defaults to `10`.

### `max_connection_error`

Max number of acceptable connection errors. Defaults to `5`.

### `connect_retry_interval`, `connect_retry_random_factor`

Options for adjusting an interval of retry that a client tries to reconnect to same node when connection error is occurred.
Defaults to `0.001` (sec) and `0.1` respectively.

A retry interval is proportional to a random value sampled from `[connect_retry_interval - connect_retry_random_factor, connect_retry_interval + connect_retry_random_factor]`.

### `connection_adapter`

Adapter name of internal connection that client uses to connect to Redis node. Defaults to `:redis`.

Available adapter is `:redis` so far.

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake test` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/saidie/renoir. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [Contributor Covenant](http://contributor-covenant.org) code of conduct.


## License

The gem is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).

The original code is from [antirez/redis-rb-cluster](https://github.com/antirez/redis-rb-cluster).
