require 'active_record'

class BaseModel < ActiveRecord::Base

  ActiveRecord::Base.establish_connection(adapter: 'sqlite3', database: File.expand_path('.', __dir__) + '/../../dbfile' )

  self.abstract_class = true

end