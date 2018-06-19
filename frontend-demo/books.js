var graph = graphql("http://localhost:3000/", {});

var author_id;

$(document).on("click", '#all tbody tr', function (tr) {
    var id = $(tr.target.parentNode).data('id');
    setBook(id);
});

$("#btnDelete").click(function (el) {
    el.preventDefault();

    var id = $('#book_id').val();

    $(this).attr('disabled', true);
    $("#btnSubmit").attr('disabled', true);
    deleteBook(id);
});

$("#btnSubmit").click(function (el) {
    el.preventDefault();

    $(this).attr('disabled', true);
    $("#btnDelete").attr('disabled', true);

    var id = $('#book_id').val();
    var title = $('#title').val();

    if (id == null || id == "") {
        console.log('save book');
        saveBook(title);
    } else {
        console.log('update book');
        updateBook(id, title);
    }
});

function setBook(id) {
    var q = `{Book(id: ${id}) {title}}`;
    console.log(`loading book ${id}...`);

    graph.query.run(q).then(function (r) {
        book = r.Book;
        console.log(book);
        $("#book_id").val(id);
        $("#title").val(book.title);

        $("#btnSubmit").removeAttr('disabled');
        $("#btnDelete").removeAttr('disabled');
    }).catch(function (error) {
        alert(JSON.stringify(error))
    })
}

function saveBook(title) {
    var q = `mutation Book($book: BookInput) {Book(book: $book) {id}}`;
    var vars = {book: {title: title, author_id: author_id}};
    console.log('creating book...');

    var create = graph(q);

    create(vars).then(function (r) {
        book = r.Book;
        $.notify(`Book created with id ${book.id}`, {position: "top center", autoHideDelay: 3000});

        $("#book_id").val(book.id);

        $("#btnSubmit").removeAttr('disabled');
        $("#btnDelete").removeAttr('disabled');

        bookList();
    }).catch(function (error) {
        alert(JSON.stringify(error))
    })
}

function updateBook(id, title) {
    var q = `mutation UpdateBook($book: BookInput) {UpdateBook(book: $book) {id}}`;
    var vars = {book: {id: id, title: title}};
    console.log(`updating book ${id}...`);

    var update = graph(q);

    update(vars).then(function (r) {
        book = r.UpdateBook;
        $.notify(`Book updated`, {position: "top center", autoHideDelay: 3000});

        $("#btnSubmit").removeAttr('disabled');
        $("#btnDelete").removeAttr('disabled');

        bookList();
    }).catch(function (error) {
        alert(JSON.stringify(error))
    })
}

function deleteBook(id) {
    var q = `mutation DeleteBook($id: ID) {DeleteBook(id: $id)}`;
    var vars = {id: id};
    console.log(`deleting book ${id}...`);

    var del = graph(q);

    del(vars).then(function (r) {
        $.notify(`Book ${id} deleted.`, {position: "top center", autoHideDelay: 3000});

        $('#book_id').val(null);
        $('#title').val(null);

        bookList();
    }).catch(function (error) {
        alert(JSON.stringify(error))
    })
}

function bookList() {
    if (author_id == null) { return }

    $("#all > tbody").html("");

    var q = `{
        Books(q: "author_id_eq=${author_id}") {
          id
          title
          created_at
          updated_at
       }
    }`;

    console.log(`loading books for author ${author_id}...`);

    graph.query.run(q).then(function (all) {
        all.Books.forEach(function (r) {
            $('#all tbody').append(`<tr data-id="${r.id}"><th scope="row">${r.id}</th>
                    <td>${r.title}</td>
                    <td>${r.created_at}</td>
                    <td>${r.updated_at}</td></tr>`);
        });

    }).catch(function (error) {
        alert(JSON.stringify(error));
    })
}

function populateAuthors() {
    $("#author_id").html("");

    var q = `{
        Authors {
          id
          name
       }
    }`;

    console.log('loading authors...');

    graph.query.run(q).then(function (all) {
        all.Authors.forEach(function (r) {
            var selected = (r.id == author_id ? 'selected="selected"' : '');
            $('#author_id').append(`<option ${selected} value="${r.id}">${r.name}</option>`)
        });

        bookList();
    }).catch(function (error) {
        alert(JSON.stringify(error));
    })
}

function parseParams() {
    var query = location.search.split('?')[1];

    var re = /([^&=]+)=?([^&]*)/g;
    var decodeRE = /\+/g;
    var decode = function (str) {return decodeURIComponent( str.replace(decodeRE, " ") );};
    var params = {}, e;
    while ( e = re.exec(query) ) {
        var k = decode( e[1] ), v = decode( e[2] );
        if (k.substring(k.length - 2) === '[]') {
            k = k.substring(0, k.length - 2);
            (params[k] || (params[k] = [])).push(v);
        }
        else params[k] = v;
    }
    return params;
}

function run() {
    console.log('starting...');

    var params = parseParams();
    author_id = params.author_id || 1;

    $('#author_id').change(function () {
        author_id = $(this).val();
        console.log('changed author to', author_id);

        bookList();
    });

    populateAuthors();
}