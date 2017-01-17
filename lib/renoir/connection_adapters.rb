require "renoir/connection_adapters/reply"

module Renoir
  # Adapter of backend Redis connection. {Renoir::Client} communicates with a
  # backend connection through a corresponding adapter.
  module ConnectionAdapters
    autoload :Redis, "renoir/connection_adapters/redis"
  end
end
