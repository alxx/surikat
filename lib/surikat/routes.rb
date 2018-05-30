# This is an internal utility class used to manage the GraphQL @routes, which are stored in an object dump called 'routes'.
# The routes map connections between names of queries and mutations, and methods in the _queries modules.
#
# A route has the following format:
# { query_name => {'module' => name of query module,
#                  'method' => name of method in that module,
#                  'output_type' => type to cast over the result of the method},
#                  'arguments' => hash of argument names and GraphQL types
#  }
#
# Examples:
# 'Author'  => {module: 'AuthorQueries', method: 'get', output_type: 'Author', 'arguments' => {'id' => 'ID'}},
# 'Authors' => {module: 'AuthorQueries', method: 'all', output_type: '[Author]', 'arguments' => {}}
class Routes

  def initialize
    @filename = File.expand_path('.',__dir__) + '/../../config/routes.json'
    @routes = load
  end

  def all
    @routes
  end

  def merge_query route
    @routes['queries'] ||= {}
    @routes['queries'].merge!(route)
    save
  end

  def merge_mutation route
    @routes['mutations'] ||= {}
    @routes['mutations'].merge!(route)
    save
  end

  def delete_query query_name
    raise "Query #{query_name} not found" if @routes['queries'].nil? || !(@routes['queries']&.keys&.include?(query_name))
    @routes['queries'].delete query_name
    save
  end

  def delete_mutation mutation_name
    aise "Mutation #{mutation_name} not found" if @routes['mutations'].nil? || !(@routes['mutations']&.keys&.include?(mutation_name))
    @routes['mutations'].delete mutation_name
    save
  end

  def clear
    @routes = {}
    save
  end

  private
  def load
    return {} unless File.exists?(@filename)
    Oj.load File.read(@filename)
  end

  def save
    File.open(@filename, 'w') { |file| file.write(JSON.pretty_generate(@routes))}
  end


end