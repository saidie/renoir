module Renoir
  module ConnectionAdapters
    # Reply for {Renoir::Client}.
    module Reply
      class Base
        attr_reader :cause

        def initialize(cause)
          @cause = cause
        end
      end

      class RedirectionError < Base
        attr_reader :ask, :ip, :port

        def initialize(cause, ask, ip, port)
          super(cause)
          @ask = ask
          @ip = ip
          @port = port
        end
      end

      class ConnectionError < Base
      end
    end
  end
end
