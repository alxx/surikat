module NewApp

  # Generate a new Surikat app with a Hello World query in it.
  def new_app(arguments)
    app_name = arguments.first

    if app_name.nil?
      puts "Usage: surikat new app_name\nCreates a new, empty Surikat app"
      return
    end

    # Create app directory structure
    create_dirs app_name

    # Create initial files
    {
        'Gemfile'                => {path: app_name},
        'Rakefile'               => {path: app_name},
        '.standalone_migrations' => {path: app_name},
        '.rspec'                 => {path: app_name},
        'config.ru'              => {path: app_name, vars: {app_name_capitalized: app_name.capitalize}},
        'hello_queries.rb'       => {path: "#{app_name}/app/queries"},
        'console'                => {path: "#{app_name}/bin"},
        'routes.yml'             => {path: "#{app_name}/config"},
        'database.yml'           => {path: "#{app_name}/config"},
        'application.yml'        => {path: "#{app_name}/config"},
        'spec_helper.rb'         => {path: "#{app_name}/spec"},
        'test_helper.rb'         => {path: "#{app_name}/spec"},
        'hello_spec.rb'          => {path: "#{app_name}/spec"}
    }.each do |name, details|
      print "Create #{name}... "
      copy_template name, details
      puts 'ok'
    end

    # Post-templating...
    FileUtils.chmod '+x', "#{app_name}/bin/console"

    `cd #{app_name} && rake db:migrate`

    # Show help :)
    show_help app_name
  end

  def create_dirs app_name
    dirs = [nil, '/bin', '/app/models', '/app/queries', '/log', '/tmp/pids', '/config/initializers', '/db', '/spec']
    dirs.each do |dir|
      print "Create directory #{app_name}#{dir}... "
      FileUtils.mkdir_p "#{app_name}#{dir}"
      puts "ok"
    end
  end

  def show_help app_name
    puts <<-EOT

=================================================================
Done. What next?

cd #{app_name}
bundle install
rspec
passenger start

=================================================================
Then...
  Got GraphiQL?
    Open GraphiQL
    Enter the URL: http://localhost:3000/
    Enter the query: {Hello}

  No GraphQL client yet? Simply try from any browser, or with curl:
    http://localhost:3000/?query=%7BHello%7B

And then...?
  Generate your own scaffold:
    surikat generate scaffold Author name:string year_of_birth:integer is_any_good:boolean

  Generate examples of queries for a specific query:
    surikat exemplify Author get

  Generate your own models:
    surikat generate model Book title:string author_id:integer

  Generate a User model with full support for authentication, authorization and access:
    surikat generate aaa

  List existing routes or GraphQL types:
    surikat list routes|types

  Create a migration:
    rake db:new_migration name=Bookstore address:string name:string
  or
    surikat generate migration AddNumberToBookstore no:integer

  Run migrations:
    rake db:migrate

    (More about migrations: https://github.com/thuss/standalone-migrations )
 
  Run generated tests:
    rspec 
    (or, more interesting, rspec -f d)

EOT
  end

end