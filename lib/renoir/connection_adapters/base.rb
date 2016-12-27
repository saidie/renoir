module Renoir
  module ConnectionAdapters
    class Base
      class << self
        def get_keys_from_command(command)
          fail "a connection adapter must override #get_keys_from_command"
        end
      end

      def call(command, asking=false, &block)
        fail "a connection adapter must override #call"
      end

      def with_raw_connection
        fail "a connection adapter must override #with_raw_connection"
      end
    end
  end
end
