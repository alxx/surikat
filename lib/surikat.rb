require('surikat/version')

module Surikat
  %w(active_support graphql/libgraphqlparser surikat/yaml_configurator).each {|g| require g}

  class << self
    def config
      @config ||= OpenStruct.new({
                                     app: YamlConfigurator.config_for('application', ENV['RACK_ENV']),
                                     db:  YamlConfigurator.config_for('database', ENV['RACK_ENV'])
                                 })
    end
  end

  %w(base_queries base_model base_type).each {|g| require "surikat/#{g}"}

  # Require all models and queries
  %w(queries models).each do |dir|
    Dir.glob("#{FileUtils.pwd}/app/#{dir}/*.rb").each {|f| require(f)}
  end

  %w(types routes session).each {|g| require "surikat/#{g}"}

  class << self
    def types
      @types ||= Types.new.all
    end

    def routes
      @routes ||= Routes.new.all
    end

    attr_accessor :options
    attr_accessor :session


    # Make sure that the type of the data (guaranteed to be scalar) conforms to the requested type.
    def cast_scalar(data, type_name)
      return nil if data.nil?

      case type_name
      when 'Int'
        data.to_i
      when 'Float'
        data.to_f
      when 'Boolean'
        {'true' => true, 'false' => false}[data.to_s]
      when 'String'
        data.to_s
      when 'ID'
        data # could be Integer or String, depending on the AR adapter
      else
        raise "Unknown type, #{type_name}"
      end
    end

    # Make sure that the type of the data conforms to what's in the requested type.
    def cast(data, type_name, is_array, field_name = nil)
      type_singular_nobang = type_name.gsub(/[\[\]\!]/, '')

      if is_array
        raise "List of data of type #{type_name} in field '#{field_name}' may not contain nil values" if type_name.include?('!') && data.include?(nil)
        result = data.to_a.map do |x|
          if Types::BASIC.include? type_singular_nobang
            cast_scalar(x, type_singular_nobang)
          else
            r              = {}
            type           = Surikat.types[type_singular_nobang]
            allowed_fields = x.keys & type['fields'].keys
            allowed_fields.each do |af|
              type_name = type['fields'][af]

              r[af] = cast(x[af], type_name, type_name.first == '[', af)
            end

            r
          end
        end
      else
        raise "Data of type #{type_name} for field '#{field_name}' may not be nil" if type_name.last == '!' && data.nil?

        if Types::BASIC.include? type_singular_nobang
          result = cast_scalar(data, type_singular_nobang)
        else
          result         = {}
          type           = Surikat.types[type_singular_nobang]
          allowed_fields = data.keys & type['fields'].keys
          allowed_fields.each do |af|
            type_name  = type['fields'][af]
            result[af] = cast(data[af], type_name, type_name.first == '[', af)
          end
        end
      end
      result
    end

    # Convert a result set into a hash (if singular)
    # or an array of hashes (if not singular) that contain only
    # the requested selectors and their values.
    def hashify(data, selections, type_name)
      puts "HASHIFY INPUT:
           \tdata: #{data.inspect}
           \tclass of data: #{data.class}
           \ttype_name: #{type_name.inspect}" if self.options[:debug]

      type_name_is_array = [type_name[0], type_name[-1]].join == '[]'

      # When no AR record was found, return a nil value rather than an empty instance
      # Sadly this causes a SELECT and I cannot find any way around it. Presumably it's a very cheap SELECT,
      # but it's still needless. :(
      if data.class.to_s.include?('ActiveRecord_Relation') && !data.exists?
        return type_name_is_array ? [] : nil
      end

      type_name_single = type_name.gsub(/[\[\]\!]/, '')

      if Types::BASIC.include? type_name_single
        type_is_basic = true
      else
        type_is_basic = false
        type          = types[type_name_single]
        fields        = type['fields']
        superclass = Object.const_get(type_name_single).superclass rescue nil
      end

      shallow_selectors, deep_selectors = selections.partition {|sel| sel.selections.empty?}

      if superclass.to_s.include? 'Surikat::BaseModel' # AR models have table_selectors because they have tables
        column_names = Object.const_get(type_name_single).column_names rescue []

        table_selectors, method_selectors = shallow_selectors.partition do |sel|
          column_names.include?(sel.name) && sel.arguments.empty? # a table selector becomes method selector if it has arguments.
        end

      else
        table_selectors  = []
        method_selectors = shallow_selectors
      end

      puts "
           \ttype_name_single: #{type_name_single}
           \tfields: #{fields.inspect}
           \tsuperclass: #{superclass}
           \tbasic type: #{type_is_basic}
           \tcolumn names: #{column_names}
           \ttable selectors: #{table_selectors.map(&:name).join(', ')}
           \tmethod selectors: #{method_selectors.map(&:name).join(', ')}
           \tdeep selectors: #{deep_selectors.map(&:name).join(', ')}
           \tshallow selectors: #{shallow_selectors.map(&:name).join(', ')}
           \ttype_name is array: #{type_name_is_array}
           \tdata is pluckable: #{data.respond_to?(:pluck).inspect}" if self.options[:debug]


      return cast(data, type_name, type_name_is_array, type_name) if type_is_basic
      data = data.first if !type_name_is_array && data.class.to_s == 'ActiveRecord::Relation'

      return({errors: data&.errors&.to_a}) if data.respond_to?(:errors) && data.errors.to_a.any?

      unless type_name_is_array # data is a single record
        hashified_data = {}

        unless table_selectors.empty?
          if data.respond_to?(:pluck) && method_selectors.empty? && deep_selectors.empty?
            unique_table_selector_names = table_selectors.map(&:name).uniq
            plucked_data                = data.pluck(*unique_table_selector_names).flatten
            unique_table_selector_names.each_with_index do |s_name, idx|
              hashified_data[s_name] = cast(plucked_data[idx], fields[s_name], false, s_name)
            end
          else
            method_selectors += table_selectors
          end
        end

        data = data.first if data.class.to_s.include?('ActiveRecord') && (method_selectors.any? || deep_selectors.any?)

        method_selectors.each do |s|
          if data.is_a? Hash
            accepted_arguments = []
          else
            accepted_arguments = data.class.instance_method(s.name)&.parameters&.select {|p| [p.first == :req]}&.map(&:last)
          end
          allowed_arguments = accepted_arguments.map {|aa| s.arguments.detect {|qa| qa.name.to_s == aa.to_s}&.value}

          uncast                 = data.is_a?(Hash) ? (data[s.name] || data[s.name.to_sym]) : data.send(s.name, *allowed_arguments)
          hashified_data[s.name] = cast(uncast, fields[s.name], uncast.is_a?(Array), s.name)
        end

        deep_selectors.each do |s|
          uncast                 = if data.is_a? Hash
                                     data[s.name] || data[s.name.to_sym]
                                   else
                                     deeper = data.send(s.name)
                                     hashify(deeper, s.selections, fields[s.name])
                                   end
          hashified_data[s.name] = cast(uncast, fields[s.name], uncast.is_a?(Array), s.name)
        end
      else # data is a set of records
        hashified_data = []
        # if there are no method selectors, use +pluck+ to optimise.
        if method_selectors.empty? && deep_selectors.empty? && !table_selectors.empty?
          data.pluck(*(table_selectors.map(&:name).uniq)).each do |record|
            hash = {}

            if table_selectors.size == 1 # if there's only one table selector, pluck returns a flatter array
              fname       = table_selectors.first.name
              hash[fname] = cast(record, fields[fname], false, fname)
            else
              table_selectors.each_with_index do |s, idx|
                hash[s.name] = cast(record[idx], fields[s.name], false, s.name)
              end
            end


            deep_selectors.each do |s|
              accepted_arguments = record.class.instance_method(s.name)&.parameters&.select {|p| [p.first == :req]}&.map(&:last)
              allowed_arguments  = accepted_arguments.map {|aa| s.arguments.detect {|qa| qa.name.to_s == aa.to_s}&.value}

              uncast       = hashify(
                  record.send(s.name, *allowed_arguments),
                  s.selections,
                  fields[s.name]
              )
              hash[s.name] = cast(uncast, fields[s.name], uncast.is_a?(Array), s.name)
            end
            hashified_data << hash
          end
        else # We have method selectors, so we retrieve the entire records and then we can call the method selectors.
          data.each do |record|
            hash = {}

            # We need to cast the records into their type data so that we have access to their specific methods.
            if superclass == BaseType
              record = type_name_single.constantize.new(record)
            end

            shallow_selectors.each do |s|
              if record.is_a? Hash
                accepted_arguments = []
              else
                accepted_arguments = record.class.instance_method(s.name)&.parameters&.select {|p| [p.first == :req]}&.map(&:last)
              end

              allowed_arguments = accepted_arguments.map {|aa| s.arguments.detect {|qa| qa.name.to_s == aa.to_s}&.value}

              uncast       = record.is_a?(Hash) ? (record[s.name] || record[s.name.to_sym]) : record.send(s.name, *allowed_arguments)
              hash[s.name] = cast(uncast, fields[s.name], uncast.is_a?(Array), s.name)
            end

            deep_selectors.each do |s|
              uncast       = hashify(
                  record.is_a?(Hash) ? (record[s.name] || record[s.name.to_sym]) : record.send(s.name),
                  s.selections,
                  fields[s.name]
              )
              hash[s.name] = cast(uncast, fields[s.name], uncast.is_a?(Array), s.name)
            end

            hashified_data << hash
          end
        end
      end

      hashified_data
    end

    def validate_arguments(given, expected)
      expected ||= {}
      given    ||= {}

      required = expected.keys.select {|k| expected[k].include?('!')}

      # Make sure all required arguments are present
      return false unless (required & given.keys) == required

      # Make sure no unknown arguments exist
      return false unless (given.keys - expected.keys).empty?

      given.each do |k, v|
        given[k] = cast_scalar(v, expected[k])
      end

      given
    end

    def check_variables(variables, variable_definition)
      variable_definition.each do |expected_var_name, expected_var_type|
        value = variables[expected_var_name]

        expected_var_type_singular = expected_var_type.gsub(/[\[\]]/, '')
        expected_var_type_simple   = expected_var_type.gsub(/[\[\]\!]/, '')
        is_plural                  = [expected_var_type.first, expected_var_type.last] == %w([ ])

        if is_plural
          unless value.is_a? Array
            raise "Variable '#{expected_var_name}' should be an array; its expected type is #{expected_var_type}."
          end

          value.each do |v_value|
            check_variables({v_value => v_value}, {v_value => expected_var_type_singular})
          end
        else # singular type
          if Types::BASIC.include?(expected_var_type_simple)

            if value.nil?
              if expected_var_type.include?('!')
                raise "Variable '#{expected_var_name}' is not allowed to be nil; its expected type is #{expected_var_type}."
              end
            end

            unless cast_scalar(value, expected_var_type_simple) == value
              raise "Variable '#{expected_var_name}' is of type #{value.class.to_s} which is incompatible with the expected type #{expected_var_type}"
            end
          else
            Types.new.all[expected_var_type]['arguments'].each do |arg_name, arg_type|
              check_variables({arg_name => variables[expected_var_name][arg_name]}, {arg_name => arg_type})
            end
          end
        end
      end

      true
    end

    def invalid_selectors(given, expected)
      expected_singular = expected.gsub(/[\[\]\!]/, '')

      if Types::BASIC.include?(expected_singular)
        expected_type = {'fields' => {}}
      else
        expected_type = Types.new.all[expected_singular]
      end

      given.selections.map(&:name) - expected_type['fields'].keys
    end

    # Turn a parsed query into a response by means of a routing table
    # Returns the response, suitable for serialization, and an errors array.
    def query(selection)
      name  = selection.name
      route = routes['queries'][name]

      return([nil, [{unknownQueryName: true}]]) if route.nil?
      return([nil, [{accessDenied: true}]]) unless allowed?(route)

      arguments = {}
      selection.arguments.each do |argument|
        arguments[argument.name] = argument.value
      end

      unless cast_arguments = validate_arguments(arguments, route['arguments'])
        error = "Expected arguments: {#{route['arguments'].to_a.map {|k, v| "#{k} (#{v})"}.join(', ')}}. Received instead {#{arguments.to_a.map {|k, v| "#{k}: #{v}"}.join(', ')}}."
        return([nil, [{argumentError: error}]])
      end

      invalid_s = invalid_selectors(selection, route['output_type'])
      return([nil, [{selectorError: "Invalid selectors: #{invalid_s.join(', ')}"}]]) unless invalid_s.empty?

      queries = Object.const_get(route['class']).new(cast_arguments, self.session)
      data    = queries.send(route['method'])

      return([nil, [{noResult: true}]]) if data.nil? || data.class.to_s == 'ActiveRecord::Relation' && !data.exists?

      begin
        hashified_data = hashify(data, selection.selections, route['output_type'])
        if hashified_data.is_a?(Hash) && hashified_data[:errors]
          [nil, hashified_data[:errors]]
        else
          [hashified_data, []]
        end
      rescue Exception => e
        puts "EXCEPTION: #{e.message}\n#{e.backtrace.join("\n")}"
        return([nil, [{error: e.message}]])
      end

    end

    # Turn a parsed mutation into a response suitable for serialization.
    # Returns the Hash object and an errors array.
    def mutation(selection, variable_definitions, variables)
      name  = selection.name
      route = routes['mutations'][name]

      return([nil, [{unknownQueryName: true}]]) if route.nil?
      return([nil, [{accessDenied: true}]]) unless allowed?(route)

      begin
        check_variables(variables, variable_definitions)
      rescue Exception => e
        return([nil, [variableError: e.message]])
      end

      queries = Object.const_get(route['class']).new(variables, self.session)
      data    = queries.send(route['method'])

      begin
        hashified_data = hashify(data, selection.selections, route['output_type'])
        if hashified_data.is_a?(Hash) && hashified_data[:errors]
          [nil, hashified_data[:errors]]
        else
          [hashified_data, []]
        end
      rescue Exception => e
        puts "EXCEPTION: #{e.message}\n#{e.backtrace.join("\n")}"
        return([nil, [error: e.message]])
      end

    end

    # Check if AAA is enabled and the route passes. If the route contains no +permitted_roles+ then
    # it's assumed to be public. If the value of +permitted_roles+ is "any", then it's assumed to be
    # private regardless of the role of the current user. If the value of +permitted_roles+ is an Array,
    # then the route will be accepted if there's an intersection between the required roles and the role of
    # the current user.
    def allowed?(route)
      return true if route['permitted_roles'].nil?

      session = self.session || {}

      if route['permitted_roles']
        unless session[:user_id]
          puts "Route is private but there is no current user." if self.options[:debug]
          false
        else
          if route['permitted_roles'] == 'any'
            true
          else
            current_user = User.where(id: session[:user_id]).first
            if (route['permitted_roles'].to_a & current_user.roleids.to_s.split(',').map(&:strip)).empty?
              puts "Route is private and requires roles #{route['permitted_roles'].inspect} but current user has roles #{current_user.roleids.inspect}" if self.options[:debug]
              false
            else
              true
            end
          end
        end
      end

    end

    def run(query, variables = nil, options = {})
      self.options = options
      parsed_query = GraphQL.parse query

      self.session = options[:session_key].blank? ? {} : Surikat::Session.new(options[:session_key])

      data   = {}
      errors = []

      parsed_query.definitions.each do |definition|
        case definition.operation_type

        when 'query'
          definition.selections.each do |selection|
            q_result, q_errors = query(selection)
            errors             += q_errors

            data[selection.name] = q_result
          end

        when 'mutation'
          variable_definitions = {}
          definition.variables.each {|v| variable_definitions[v.name] = v.type.name}

          definition.selections.each do |selection|
            q_result, q_errors = mutation(selection, variable_definitions, variables)
            errors             += q_errors

            data[selection.name] = q_result
          end
        end
      end

      result = {data: data}
      result.merge!({errors: errors}) unless errors.empty?

      result
    end
  end
end
