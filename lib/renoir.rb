require "renoir/version"
require "renoir/client"

module Renoir
  class BaseError < RuntimeError
  end

  class RedirectionError < BaseError
  end
end
