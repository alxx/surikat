# This is an internal utility class used to manage the GraphQL types, which are stored in an object dump called 'types.json'.
# The developers will use this class to CRUD their GraphQL application types. The scaffold generators will also
# use this class for the same purpose.
class Types

  BASIC = ['Int', 'Boolean', 'String', 'Float', 'ID']

  def initialize
    @filename = File.expand_path('.',__dir__) + '/../../config/types.json'
    @types = load
  end

  def all
    @types
  end

  def merge type
    @types.merge! type
    save
  end

  def delete type_name
    raise "Type #{type_name} not found" unless @types.keys.include?(type_name)
    @types.delete type_name
    save
  end

  def clear
    @types = {}
    save
  end

  private
  def load
    return {} unless File.exists?(@filename)
    Oj.load File.read(@filename)
  end

  def save
    File.open(@filename, 'w') { |file| file.write(JSON.pretty_generate(@types))}
  end

end