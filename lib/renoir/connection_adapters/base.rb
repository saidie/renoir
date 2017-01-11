module Renoir
  module ConnectionAdapters
    # Abstract class.
    class Base
      class << self
        # Return keys in a `command`.
        #
        # @param [Array] command a command argument
        # @return [Array<String>] keys
        def get_keys_from_command(command)
          fail "a connection adapter must override #get_keys_from_command"
        end
      end

      # Call pipelined commands.
      #
      # @param [Array<Array>] commands list of commands.
      # @param [Boolean] asking Call ASKING command at first if `true`
      # @yield [Object] a connection backend may yield
      def call(commands, asking=false, &block)
        fail "a connection adapter must override #call"
      end

      # Close a backend connection.
      def close
        fail "a connection adapter must override #close"
      end

      # Return a backend connection.
      #
      # @return [Object] a backend connection instance
      def with_raw_connection
        fail "a connection adapter must override #with_raw_connection"
      end
    end
  end
end
