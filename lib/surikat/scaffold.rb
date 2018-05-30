module Scaffold

  require 'fileutils'

  def generate_routes(model_name, is_aaa: false)
    print "Generating query and migration routes... "

    routes = Routes.new

    class_name = ActiveSupport::Inflector.camelize(model_name)

    begin
      # get one query
      routes.merge_query({class_name => {
          'class'       => "#{class_name}Queries",
          'method'      => 'get',
          'output_type' => "#{class_name}",
          'arguments'   => {'id' => 'ID'}
      }})

      # get all query
      class_name_plural = ActiveSupport::Inflector.pluralize(class_name)
      routes.merge_query({class_name_plural => {
          'class'       => "#{class_name}Queries",
          'method'      => 'all',
          'output_type' => "[#{class_name}]",
          'arguments'   => {'q' => 'String'}
      }})

      # create mutation
      routes.merge_mutation({class_name => {
          'class'       => "#{class_name}Queries",
          'method'      => 'create',
          'output_type' => "#{class_name}",
          'arguments'   => {class_name => "#{class_name}Input"}
      }})

      # update mutation
      routes.merge_mutation({"Update#{class_name}" => {
          'class'       => "#{class_name}Queries",
          'method'      => 'update',
          'output_type' => "Boolean",
          'arguments'   => {class_name => "#{class_name}Input"}
      }})

      # delete mutation
      routes.merge_mutation({"Delete#{class_name}" => {
          'class'       => "#{class_name}Queries",
          'method'      => 'delete',
          'output_type' => "Boolean",
          'arguments'   => {'id' => 'ID'}
      }})

      if is_aaa # add extra routes for AAA
        routes.merge_query({'Authenticate' => {
            "class"       => "AAAQueries",
            "method"      => "authenticate",
            "output_type" => "Boolean",
            "arguments"   => {
                "email"    => "String",
                "password" => "String"
            }
        }})

        routes.merge_query({'Logout' => {
            "class"           => "AAAQueries",
            "method"          => "logout",
            "output_type"     => "Boolean",
            "permitted_roles" => "any"
        }})

        routes.merge_query({'CurrentUser' => {
            "class"           => "AAAQueries",
            "method"          => "current_user",
            "output_type"     => "User",
            "permitted_roles" => "any"
        }})

        routes.merge_query({'LoginAs' => {
            "class"           => "AAAQueries",
            "method"          => "login_as",
            "output_type"     => "Boolean",
            "permitted_roles" => ["superadmin"],
            "arguments"       => {
                "user_id" => "ID"
            }
        }})

        routes.merge_query({'BackFromLoginAs' => {
            "class"           => "AAAQueries",
            "method"          => "back_from_login_as",
            "output_type"     => "Boolean",
            "permitted_roles" => "any"
        }})

        routes.merge_query({'DemoOne' => {
            "class"           => "AAAQueries",
            "method"          => "demo_one",
            "output_type"     => "String",
            "permitted_roles" => "any"
        }})

        routes.merge_query({'DemoTwo' => {
            "class"           => "AAAQueries",
            "method"          => "demo_two",
            "output_type"     => "String",
            "permitted_roles" => ["hotdog", "hamburger"]
        }})

        routes.merge_query({'DemoThree' => {
            "class"           => "AAAQueries",
            "method"          => "demo_three",
            "output_type"     => "String",
            "permitted_roles" => ["worker"]
        }})
      end # if is_aaa
    rescue Exception => e
      puts "fail: #{e.message}, #{e.backtrace.first}"
      false
    else
      puts "ok"
      true
    end
  end

  def destroy_routes(model_name)
    class_name        = ActiveSupport::Inflector.camelize(model_name)
    class_name_plural = ActiveSupport::Inflector.pluralize(class_name)

    routes = Routes.new

    print "Destroying query and mutation routes... "

    begin
      routes.delete_query class_name
      routes.delete_query class_name_plural
      routes.delete_mutation class_name
      routes.delete_mutation "Update#{class_name}"
      routes.delete_mutation "Delete#{class_name}"
    rescue Exception => e
      puts "fail: #{e.message}, #{e.backtrace.first}"
      false
    else
      puts "ok"
      true
    end
  end

  def generate_queries(model_name)
    var_name           = ActiveSupport::Inflector.singularize(model_name.underscore)
    class_name         = ActiveSupport::Inflector.camelize(model_name)
    class_name_plural  = ActiveSupport::Inflector.pluralize(class_name)
    file_name          = ActiveSupport::Inflector.singularize(model_name.underscore) + '_queries.rb'
    file_path          = "queries/#{file_name}"
    absolute_path      = FileUtils.pwd + '/app/'
    file_absolute_path = absolute_path + file_path

    FileUtils.mkdir_p absolute_path + 'models'

    print "Generating query file #{file_path}... "

    if File.exists?(file_absolute_path)
      puts "exists"
      return true
    end

    all_types = Types.new.all

    input_type_detailed = all_types["#{class_name}Input"]['arguments'].map do |field, type|
      "   '#{field}' => #{type}"
    end.join("\n")

    input_type_detailed_no_id = all_types["#{class_name}Input"]['arguments'].map do |field, type|
      next if field == 'id'
      "   '#{field}' => #{type}"
    end.compact.join("\n")

    fields = all_types[class_name]['fields'].keys

    examples = {
        get:    "{\n  #{class_name}(id: 123) {\n" + fields.map {|f| "    #{f}"}.join("\n") + "\n  }\n}",
        list:   "{\n  #{class_name_plural}(q: \"id_lt=100\") {\n" + fields.map {|f| "    #{f}"}.join("\n") + "\n  }\n}",
        create: "mutation #{class_name}($#{var_name}: #{class_name}Input) {\n  #{class_name}(#{var_name}: $#{var_name}) {\n" + fields.map {|f| "    #{f}"}.join("\n") + "\n  }\n}",
        update: "mutation Update#{class_name}($#{var_name}: #{class_name}Input) {\n  Update#{class_name}(#{var_name}: $#{var_name}) {\n" + fields.map {|f| "    #{f}"}.join("\n") + "\n  }\n}",
        delete: "mutation Delete#{class_name}($id: ID) {\n  Delete#{class_name}(id: $id)\n}"
    }

    update_vars = {var_name => {}}
    all_types["#{class_name}Input"]['arguments'].each {|a, t| update_vars[var_name][a] = random_values(t)}

    create_vars = {var_name => {}}
    all_types["#{class_name}Input"]['arguments'].each {|a, t| create_vars[var_name][a] = random_values(t)}
    create_vars[var_name].delete 'id'

    vars = {
        examples:                  examples,
        time:                      Time.now.to_s,
        class_name_downcase:       class_name.underscore,
        class_name:                class_name,
        class_name_plural:         class_name_plural,
        input_type_detailed:       input_type_detailed,
        pretty_update_vars:        JSON.pretty_generate(update_vars),
        pretty_create_vars:        JSON.pretty_generate(create_vars),
        pretty_random_id:          JSON.pretty_generate({'id' => random_values('ID')}),
        input_type_detailed_no_id: input_type_detailed_no_id,
        examples_get:              examples[:get],
        examples_list:             examples[:list],
        examples_create:           examples[:create],
        examples_update:           examples[:update],
        examples_delete:           examples[:delete]
    }

    copy_template 'crud_queries.rb', {new_name: file_name, path: 'app/queries', vars: vars}

    puts "ok"
    true
  end

  def generate_aaa_queries
    file_name          = 'aaa_queries.rb'
    file_path          = "app/queries/#{file_name}"
    absolute_path      = FileUtils.pwd + '/app/queries/'
    file_absolute_path = absolute_path + file_path

    vars = {
        time: Time.now.to_s
    }

    print "Creating AAA queries file: #{file_name}... "

    if File.exists?(file_absolute_path)
      puts "exists"
      return true
    end

    copy_template file_name, {path: 'app/queries', vars: vars}

    puts "ok"
    true
  end

  def destroy_queries(model_name)
    file_name = ActiveSupport::Inflector.singularize(model_name.underscore) + '_queries.rb'
    file_path = "queries/#{file_name}"

    print "Deleting queries file: #{file_path}... "

    begin
      File.unlink FileUtils.pwd + '/app/' + file_path
    rescue Exception => e
      puts "fail: #{e.message}"
      false
    else
      puts "ok"
      true
    end
  end

  def generate_types(model_name, arguments, is_aaa: false)
    type_name = ActiveSupport::Inflector.camelize(model_name)
    types     = Types.new

    fields = {}
    (arguments + ['id:ID']).each do |arg|
      field_name, field_type = arg.split(':').map(&:strip)

      next if field_name.in?(%w(password hashed_password)) && is_aaa # never expose the hashed password

      field_type = 'ID' if field_name[-3, 3] == '_id'

      graphql_type = case field_type
                     when 'ID'
                       'ID'
                     when 'integer'
                       'Int'
                     when 'float'
                       'Float'
                     when 'string', 'text'
                       'String'
                     when 'boolean'
                       'Boolean'
                     else
                       'String'
                     end

      fields[field_name] = graphql_type
    end

    print "Generating output type... "

    if types.all.keys.include?(type_name)
      puts "exists"
    else
      begin
        types.merge type_name => {
            'type'   => 'Output',
            'fields' => fields.clone
        }
      rescue Exception => e
        puts "fail: #{e.message}, #{e.backtrace.first}"
        return false
      else
        puts "ok"
      end
    end

    print "Generating input type... "

    if types.all.keys.include?("#{type_name}Input")
      puts "exists"
      true
    else
      input_fields = fields.clone

      if is_aaa
        input_fields.merge!({'password' => 'String'})
        input_fields.delete('hashed_password')
      end

      begin
        types.merge "#{type_name}Input" => {
            'type'      => 'Input',
            'arguments' => input_fields
        }
      rescue Exception => e
        puts "fail: #{e.message}, #{e.backtrace.first}"
        false
      else
        puts "ok"
        true
      end
    end
  end

  def destroy_types(model_name)
    print "Deleting types... "

    begin
      type_name = ActiveSupport::Inflector.camelize(model_name)
      types     = Types.new

      types.delete(type_name)
      types.delete("#{type_name}Input")
    rescue Exception => e
      puts "fail: #{e.message}, #{e.backtrace.first}"
      false
    else
      puts "ok"
      true
    end
  end

  def make_create_migration(migration_name, arguments)
    print "Creating migration #{migration_name}... "

    arguments << 'created_at:datetime'
    arguments << 'updated_at:datetime'

    begin
      StandaloneMigrations::Generator.migration migration_name, arguments
    rescue Exception => e
      puts " error: #{e.message}"
      return false
    else
      puts "ok"
      true
    end
  end

  def generate_model(model_name, arguments, is_aaa: false)
    class_name         = ActiveSupport::Inflector.camelize(model_name)
    file_name          = ActiveSupport::Inflector.singularize(model_name.underscore) + '.rb'
    file_path          = "models/#{file_name}"
    absolute_path      = FileUtils.pwd + '/app/'
    file_absolute_path = absolute_path + file_path

    return false unless make_create_migration("create_#{model_name}", arguments)

    FileUtils.mkdir_p absolute_path + 'models'

    print "Creating model file: #{file_name}... "

    if File.exists?(file_absolute_path)
      puts "exists"
      return true
    end

    template = is_aaa ? 'base_aaa_model.rb' : 'base_model.rb'

    copy_template template, {new_name: file_name, path: 'app/models', vars: {class_name: class_name}}

    puts "ok"
    return true
  end

  def generate_tests(model_name, arguments, is_aaa: false)

    class_name         = ActiveSupport::Inflector.camelize(model_name)
    class_name_plural  = ActiveSupport::Inflector.pluralize(class_name)
    model_name_plural  = ActiveSupport::Inflector.pluralize(model_name.underscore)
    file_name          = ActiveSupport::Inflector.singularize(model_name.underscore) + '_spec.rb'
    file_path          = "spec/#{file_name}"
    absolute_path      = FileUtils.pwd + '/app/'
    file_absolute_path = absolute_path + file_path
    columns            = (arguments.to_a.map {|a| a.split(':').first} + %w(id created_at updated_at)).uniq

    columns            -= ['hashed_password'] if is_aaa

    print "Creating rspec tests: #{file_name}... "

    if File.exists?(file_absolute_path)
      puts "exists"
      return true
    end

    copy_template 'base_spec.rb', {
        new_name: file_name,
        path:     'spec',
        vars:     {class_name:       class_name, class_name_plural: class_name_plural,
                   model_name:       model_name.underscore, model_name_plural: model_name_plural,
                   columns_new_line: columns.join("\n           "),
                   columns_space:    columns.map {|c| "'#{c}'"}.join(', ')
        }
    }

    puts "ok"

    if is_aaa
      print "Creating AAA rspec tests: spec/aaa_spec.rb... "
      copy_template 'aaa_spec.rb', {path: 'spec'}
      puts "ok"
    end

    true
  end

  def generate_scaffold arguments
    model_name = arguments.shift
    if model_name.to_s.empty?
      puts "Syntax: surikat generate scaffold model_name field1:type1 field2:type2..."
      return
    end

    unless model_name =~ /^[\p{L}_][\p{L}\p{N}@$#_]{0,127}$/
      puts "'#{model_name}' does not appear to be a valid."
      return
    end

    valid_types = %w(integer float string boolean date datetime decimal binary bigint primary_key references string text time timestamp)

    arguments.each do |arg|
      field_name, field_type = arg.split(':')
      unless field_name =~ /^[\p{L}_][\p{L}\p{N}@$#_]{0,127}$/
        puts "'#{field_name} does not appear to be valid'"
        return
      end
      unless valid_types.include?(field_type)
        puts "'#{field_type}' does not appear to be valid. Valid field types are: #{valid_types.join(', ')}"
      end
    end

    if generate_model(model_name, arguments) &&
        generate_types(model_name, arguments) &&
        generate_queries(model_name) &&
        generate_routes(model_name) &&
        generate_tests(model_name, arguments)
      puts "Done."
    else
      puts "Partially done."
    end

  end

  def generate_aaa
    model_name = 'user'
    arguments  = ['email:string', 'hashed_password:string', 'roleids:string']

    if generate_model(model_name, arguments, is_aaa: true) &&
        generate_types(model_name, arguments, is_aaa: true) &&
        generate_queries(model_name) &&
        generate_aaa_queries &&
        generate_routes(model_name, is_aaa: true)
      generate_tests(model_name, arguments, is_aaa: true)

      puts "Done."
    else
      puts "Partially done."
    end
  end

  def copy_template name, details
    destination_path = details[:path]
    vars             = details[:vars] || {}
    file             = "#{__dir__}/templates/#{name}.tmpl"
    dest             = "#{destination_path}/#{details[:new_name] || name}"

    text = File.open(file).read

    File.open(dest, 'w') {|f| f.write(text % vars)}
  end


end