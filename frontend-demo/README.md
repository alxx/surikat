# Surikat Demo

This is a collection of three HTML pages which test a few basic [Surikat](https://github.com/alxx/surikat) features.
The layout is based on [Bare](http://startbootstrap.com/template-overviews/bare/) by [Start Bootstrap](http://startbootstrap.com/) 
and, in addition to Bootstrap and jQuery, it uses [jquery-graphql](https://www.jquerycards.com/media/tables-graphs/jquery-graphql/).

## Page 1. Authors

The purpose of this page is to implement CRUD (create, retrieve, update and delete) operations using GraphQL.
These operations can automatically created in a Surikat app by means of a scaffold command:

```bash
$ surikat generate scaffold Author name:string yob:integer
$ rake db:migrate
```

## Page 2. Books

To further comment on Surikat's simplicity, there's a secondary page where an author's list of books
can be managed. In order for this to work, first the underlying scaffold must be generated:

```bash
$ surikat generate scaffold Book title:string
$ rake db:migrate
```

Then, the `Author` and `Book` models need to be connected

```ruby
class Author < Surikat::BaseModel
  has_many :books, dependent: :destroy
end
```

```ruby
class Book < Surikat::BaseModel
  belongs_to :author
end
```

And finally, the `Author` GraphQL type needs to include a field called `books`. So in `config/types.yml` add the last line, `books: "[Book]"`:

```yaml
Author:
  type: Output
  fields:
    name: String
    yob: Int
    age: Int
    created_at: String
    updated_at: String
    id: ID
    books: "[Book]"
```

## Page 3. AAA

The last page in this demo works with authentication, authorisation and access control (AAA).

It requires that AAA is added to the Surikat app:

```bash
$ surikat generate aaa
$ rake db:migrate
```

and that there's a user to login with:

```bash
$ bin/console
> User.create email:'a@b.c', password:'1'
```

### Live Reload

If you want to edit this demo and would like the benefits of live reloading, you can use `gulp`. First, install the necessary modules:

```bash
$ npm install
```

Then, the `gulp` command line interface:

```bash
$ npm install gulp-cli
```

Now, if you run `gulp dev` the index page will open in a browser, and it will refresh
when you make changes in the files.
