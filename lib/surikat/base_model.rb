%w(active_record ransack).each do |g|
  require g
end

module Surikat

  class BaseModel < ActiveRecord::Base
    ActiveRecord::Base.establish_connection(Surikat.config.db)

    self.abstract_class = true

    # Used when running tests
    def self.create_random
      create random_params
    end

    def self.random_params
      params = {}
      columns.each do |col|
        next if ['id', 'created_at', 'updated_at'].include?(col.name)
        params[col.name] = case col.type.to_s
                           when 'string'
                             "Some String #{SecureRandom.hex(4)}"
                           when 'float', 'integer'
                             rand(100)
                           when 'boolean'
                             [true, false].sample
                           end
      end
      params
    end
  end

end