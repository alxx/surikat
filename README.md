# Surikat

![Surikat](https://i.imgur.com/OlCUw38.png)

## A backend web framework centred around GraphQL.

Many frontend apps require little more than a simple backend that does a few CRUD operations
and handles user authentication, authorisation and access (AAA).

For even the simplest backends, frontend developers must invest time and knowledge
into some unfamiliar framework, and then code the app -- often in a language that they're not very
comfortable in.

Surikat solves much of that.

With Surikat, you can have a backend app up and running in under a minute, that does CRUD
and AAA, with no code at all.

Sure, Rails has scaffolding -- but not for AAA, and not for GraphQL. Sure, there are gems for that -- but 
they have significant learning curves.

Sure, Rails can make API-only apps -- but only REST API apps. [GraphQL](http://graphql.org), a standard created
by Facebook and made open-source since then, is far more efficient than REST. There's only
one endpoint, and you get exactly the data what you ask for -- nothing else.

Sure, Rails can also be taught GraphQL. But that's an add-on to everything else that Rails 
does; by contrast, Surikat was built, from the ground up, around GraphQL.

Writing the backend for GraphQL queries, in most existing frameworks, can be tedious and complicated.
Surikat organises, simplifies and exemplifies all queries, and it even helps a lot with testing them.
You always know how to call a query, even without introspection; Surikat is intuitive, and will always have an example handy.

### Quick Start

```bash
$ gem install surikat
$ surikat new library
```

Once the Surikat app is created, follow the instructions; `cd` into the app directory,
run `rspec` for tests, `passenger start` to start a web server, `bin/console` to try
stuff out, etc.

Just type `surikat` to see what the command line tool can do.

### Slow Start

Surikat operates with four concepts: *Routes*, *Types*, *Queries* and *Models*.

#### Models 
Surikat is not an MVC framework; it lacks the V and the C. But it does use models, and
in particular, the ActiveRecord library that Ruby on Rails was initially based on.
If you're familiar with modern MVC frameworks, then you'll feel right at home with 
Surikat models.

#### Queries
With Surikat, Queries are simple Ruby code; you don't have to learn any complicated DSL
or try to adapt to someone else's idea of what a GraphQL query definition should look like.

Each model file has a companion queries file, but you can also write your own queries.
By using some simple conventions, and routes (see below), queries can easily be
represented as simple methods:

```ruby
class AuthorQueries < Surikat::BaseQueries
  def get
    Author.where(id: arguments['id'])
  end
end
```

#### Routes
Models and Queries are the only components of Surikat which require a programming language
(Ruby). The other half are simple YAML files, which can be edited manually or 
programmatically. Routes describe the links between GraphQL queries (or mutations), and 
the queries method.

For example, the query method above might be routed thus:

```yaml
Author:
    class: AuthorQueries
    method: get
    output_type: Author
    arguments:
      id: ID
```

#### Types
You'll notice in the route above that it mentions an output_type named `Author`. Just
like routes, types live also in YAML files, and they are used to describe the data
that goes in the app (input types), and the data that comes out (output types).

In the example above, the `Author` route calls the `get` method of the `AuthorQueries` class,
and it formats its return (an `Author` database record) to match a given type. Case in point:

```yaml
Author:
  type: Output
  fields:
    name: String
    created_at: String
    updated_at: String
    id: ID
    books: "[Book]"
```
  
These are all the fields that the frontend would have access to; a `name` of the type `String`,
two timestamps which are also automatically cast as `String`, the record database id,
and an array of books (which are, in turn, rendered in accordance to their own `Book` output type).

### Examplifying Queries

Whenever you have a query, Surikat will tell you how it works, and it will even
give you a `curl` command line to test it with:

```bash
$ surikat exemplify AuthorQueries get

Query:
{
  Author(id: 1) {
    name
    created_at
    updated_at
    id
    books {
      title
      created_at
    }
  }
}


curl command:
curl 0:3000 -X POST -d 'query=%7B%0A++Author%28id%3A+1%29+%7B%0A++++name%0A++++created_at%0A++++updated_at%0A++++id%0A++++books+%7B%0A++++++title%0A++++++created_at%0A++++%7D%0A++%7D%0A%7D'
```

### Scaffolding

Surikat comes with a convenient scaffolding tool, which creates a model (with a database migration),
a set of queries for it (to Create, Retrieve, Update and Delete), as well as the necessary
types, routes and tests.

Example:

```bash
surikat generate model Book title:string
```

### Custom Data

Sometimes you need to supply for the frontend things that don't come directly from the database.
In fact, you can send anything you want; here are a few simple recipes:

 1 To add an additional field to the ones already provided by the database, the easiest way 
is to define a method in the model.

```ruby
class Person < Surikat::BaseModel
  def favourite_number
    rand(10)
  end
end
```

Then, you can add `favourite_number` into the `Author` output type, and you're set.

 2 If you need this field to have arguments:

```ruby
class Person < Surikat::BaseModel
  def square(num)
    num * num
  end
end
```

And in the query:

```graphql
{
  Person(id: 1) {
    square(num: 5)
  }
}
```

 3 Returning custom types is also easy. If you have an output type that defines the fields
`favourite_food` and `favourite_drink`, all your query needs to do is to return a Ruby `Hash`
that has those two keys.

```ruby
class MyQueries < Surikat::BaseQueries
  def favourite_stuff
    {
      favourite_food: 'air',
      favourite_drink: 'water'
    }
  end
end
```

This works for arrays, too. You can return an array of such objects, and use them 
in your output types using the brackets notation, for example `[FavouriteStuffType]`.

#### Errors

Application errors, type errors or model validation errors are return inside a field named `error`.

#### Arguments

In the queries, you always have access to the query arguments via the `arguments` helper:

```ruby
class AuthorQueries < Surikat::BaseQueries
  def get
    Author.where(id: arguments['id'])
  end
end
```

### Session

Session management is easy with Surikat. Simply carry around an HTTP header named 'Surikat' with a value that's
as randomly unique as possible. You probably want to generate this value when your frontend app loads, then use it for all
Surikat queries. As long as you send the same Surikat header, you'll maintain a session.

With curl:

```bash
curl 0:3000 -X POST -d 'query=%7B%0AHello%0A%7D' -H 'Surikat: 1234'
```
 
In the queries, you always have access to the session object via the `session` helper:

```ruby
class AuthorQueries < Surikat::BaseQueries
  def play_with_session
    # store something in the session object
    session[:something] = 'Something'
    
    # retrieve something from the session object
    {
      name: session[:name]
    }
  end
end
```

#### Session Stores

The session store is configured in `config/application.yml` and it can either be a file, or Redis.

The file method is slower, and can it gets slower as the file (which lives in `tmp/`) gets bigger. Also,
needless to say, it doesn't work to scale up the app across several machines.

Redis is much preferred especially in production; remember to add the `redis` gem to Gemfile. To configure it,
use the `url` field in the same configuration file; that will be passed to the Redis initialisation method.

### Authentication, Authorisation and Access

Surikat comes with triple-A, but it's not enabled by default. Rather, the files must be generated:

```bash
surikat generate aaa
```

This will create a `User` model (plus migration), a class called `AAAQueries` and a suite of tests.

The model will, by default, have three columns: `email`, `hashed_password` and `roleids`.

To create a user, use the `password` accessor.

```ruby
$ bin/console

User.create email:'a@b.com', password:'abc'
```

Surikat will save a SHA256 digest for that password in the database.

To restrict a query to logged in users, add `permitted_roles: any` to its route.

To restrict a query to particular user roles (more about roles below), add for example `permitted_roles: admin,superadmin` to its route.

The AAA queries available to you are described in `app/queries/aaa_queries.rb`, including even query examples.
In short, they are:

* `Authenticate` - you pass the email and password, and you get a boolean value; if the authentication
succeeds, then a `user_id` will be stored in the session object, giving you access to the current user.

* `Logout` - self-explanatory.

* `CurrentUser` - returns the current user based on what's in `session[:user_id]`.

* `LoginAs` - allows a superadmin to login as another user (more about superadmins in the Roles section below).
During this time, the session will also contain `:superadmin_id`.

* `BackFrom LoginAs` - having logged in as someone else, return as the initial superadmin.

* `DemoOne`, `DemoTwo` and `DemoThree` - used by the rspec tests. If you delete them, please also delete the corresponding tests in `spec/aaa_spec.rb`.

#### Roles

Roles are simply identifiers stored, for a user, inside the `roleids` attribute, and comma-separated.

Before a query is executed, the contents of its `permitted_roles` field (from its route) is evaluated.
If it's `any` then a user of any role is allowed access. If it's a comma separated array of role identifiers,
then access will only be granted if there's an intersection between those roles and the current user's.

### Application Structure
A Surikat app has the following directory structure:
```bash
├── Gemfile
├── Rakefile
├── app
│   ├── models
│   └── queries
├── bin
│   └── console
├── config
│   ├── application.yml
│   ├── database.yml
│   ├── initializers
│   ├── routes.yml
│   └── types.yml
├── config.ru
├── db
│   ├── migrate
├── log
├── spec
└── tmp
```

* app - models and queries. That's where all the code you need to write will be. (Except for tests.)
* bin - just the console binary. Nothing to touch here.
* config - contains the database configuration, application configuration, and any initializers.
* db - migration files, database stuff.
* log - passenger logs
* spec - tests
* tmp - pid files, temporary stuff.

### Testing

All the scaffolds come with running tests; just run `rspec` or, if you'd rather see
some details, `rspec -f d`. 

If you change the scaffolding, you need to change the tests, too.

*Note:* The intention was (and still is) to make autotests fully independent, so that they still test the scaffolded code
even after you change it. However, because of field arguments, that's not exactly trivial. Hopefully a later release will 
come with a solution to this issue. Until then, you have to adapt the tests to your code changes "by hand".

### Web Server

Surikat uses (Phusion Passenger)[https://www.phusionpassenger.com/] as a web server. Simply type

```bash
passenger serve
```

to start a server on port 3000. Then you can use GraphiQL, curl or your actual frontend app to start 
querying the backend.

#### A Note About Ransack

Surikat comes with Ransack, so that when you retrieve a collection of ActiveRecord objects, you can
already filter and sort them using [Ransack search matchers](https://github.com/activerecord-hackery/ransack#search-matchers). 

Example query:

```graphql
 {
  Authors(q: "is_any_good_eq=false&id_lt=20 ") {
    id
    name
    created_at
    is_any_good
    year_of_birth
  }
}
```

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/alxx/surikat.

## License

Author: Alex Deva (me@alxx.se)

The gem is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).
