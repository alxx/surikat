module Surikat
  class SessionManager
    def initialize
      @config = Surikat.config.app['session']

      #puts "Session manager configured with #{@config.inspect}"

      case @config['storage']
      when 'redis'
        @store = Redis.new url: @config['redis_url']
      when 'file'
        @filename = @config['file'] || 'surikat_session_store'
        @store = Marshal.load(File.read(@filename)) rescue {}
      end

    end

    attr_reader :config

    def [](key)
      case @config['storage']
      when 'file'
        @store[key]
      when 'redis'
        existing = @store.get("surikat_session_key_#{key}")
        existing ? Marshal.load(existing) : {}
      end
    end

    def merge!(key, hash)
      return if key.nil?

      case @config['storage']

      when 'redis'
        redis_key = "surikat_session_key_#{key}"
        if existing = @store.get(redis_key)
          existing_object = Marshal.load(existing)
          new_object      = existing_object.merge(hash)
        else
          new_object = hash
        end
        new_data = Marshal.dump(new_object)
        @store.set(redis_key, new_data)

      when 'file'
        if @store[key]
          @store[key].merge!(hash)
        else
          @store[key] = hash
        end
        File.open(@filename, 'w') {|f| f.write Marshal.dump(@store)}
      end

      true
    end

    def destroy!(skey)
      case @config['storage']
      when 'redis'
        @store.del("surikat_session_key_#{skey}")
      when 'file'
        @store.delete(skey)
        File.open(@filename, 'w') {|f| f.write Marshal.dump(@store)}
      end
    end

    def delete_key!(skey, key)
      case @config['storage']
      when 'redis'
        redis_key = "surikat_session_key_#{key}"
        if existing = @store.get(redis_key)
          existing_object = Marshal.load(existing)
          new_object      = existing_object.delete(key)

          new_data = Marshal.dump(new_object)
        end
        @store.set(redis_key, new_data)
      when 'file'
        @store[skey].delete(key)
        File.open(@filename, 'w') {|f| f.write Marshal.dump(@store)}
      end
    end

  end
end