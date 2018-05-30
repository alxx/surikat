module YamlConfigurator

  def self.config_for(name, env)
    yaml = Pathname.new("config/#{name}.yml")

    #puts "Loading #{name} for environment: #{env}"

    if yaml.exist?
      require "erb"
      (YAML.load(ERB.new(yaml.read).result) || {})[env] || {}
    else
      raise "Could not load configuration. No such file - #{yaml}"
    end
  rescue Psych::SyntaxError => e
    raise "YAML syntax error occurred while parsing #{yaml}. " "Please note that YAML must be consistently indented using spaces. Tabs are not allowed. " "Error: #{e.message}"
  end

end