module Surikat
  class BaseQueries
    def initialize(arguments, session)
      @arguments, @session = arguments, session
    end

    attr_reader :arguments
    attr_reader :session
  end
end