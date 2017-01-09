module Renoir
  class Pipeline
    attr_reader :commands

    def initialize(options={})
      @commands = []
    end

    def eval(*args)
      call(:eval, *args)
    end

    def call(*command)
      @commands << command
    end

    def method_missing(command, *args, &block)
      call(command, *args, &block)
    end
  end
end
