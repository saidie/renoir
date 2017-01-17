require "renoir/version"
require "renoir/client"

module Renoir
  # Base class of Renoir errors.
  class BaseError < RuntimeError
  end

  # Error related to redirection.
  class RedirectionError < BaseError
  end
end
