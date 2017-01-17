module Renoir
  class Pipeline
    attr_reader :commands

    def initialize(options={})
      @commands = []
    end

    # Delegated to {#call}.
    def eval(*args)
      call(:eval, *args)
    end

    # Store a command for pipelining.
    #
    # @param [Array] a Redis command passed to a connection backend
    def call(*command)
      @commands << command
    end

    # Delegated to {#call}.
    def method_missing(command, *args, &block)
      call(command, *args, &block)
    end
  end
end
