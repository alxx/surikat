module Surikat

  require 'surikat/session_manager'

  class Session

    def initialize(session_key)
      @manager = Surikat::SessionManager.new
      @session_key = session_key
      @this_session = @manager[session_key] || {}

      if @this_session.blank? && !@session_key.blank?
        @manager.merge! @session_key, {created_at: Time.now}
      end
    end

    def [](key)
      @this_session[key]
    end

    def []=(key, value)
      @manager.merge! @session_key, {key => value}
    end

    def delete(key)
      @manager.delete_key! @session_key, key
    end

    def to_h
      @this_session
    end

  end

end