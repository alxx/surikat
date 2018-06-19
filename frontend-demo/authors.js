var graph = graphql("http://localhost:3000/", {});

$(document).on("click", '#all tbody tr', function (tr) {
    var id = $(tr.target.parentNode).data('id');

    // simple way to ignore graphql if the click was on a link
    if (tr.target.outerHTML.indexOf('<a href') == -1) {
        setAuthor(id);
    }
});

$("#btnDelete").click(function (el) {
    el.preventDefault();

    var id = $('#author_id').val();

    $(this).attr('disabled', true);
    $("#btnSubmit").attr('disabled', true);
    deleteAuthor(id);
});

$("#btnSubmit").click(function (el) {
    el.preventDefault();

    $(this).attr('disabled', true);
    $("#btnDelete").attr('disabled', true);

    var id = $('#author_id').val();
    var name = $('#name').val();
    var yob = $('#yob').val();

    if (id == null || id === "") {
        console.log('save author');
        saveAuthor(name, yob);
    } else {
        console.log('update author');
        updateAuthor(id, name, yob);
    }
});

function setAuthor(id) {
    var q = `{Author(id: ${id}) {name,yob}}`;
    console.log(`loading author ${id}...`);

    graph.query.run(q).then(function (r) {
        author = r.Author;
        console.log(author);
        $("#author_id").val(id);
        $("#name").val(author.name);
        $("#yob").val(author.yob);

        $("#btnSubmit").removeAttr('disabled');
        $("#btnDelete").removeAttr('disabled');
    }).catch(function (error) {
        alert(JSON.stringify(error))
    })
}

function saveAuthor(name, yob) {
    var q = `mutation Author($author: AuthorInput) {Author(author: $author) {id}}`;
    var vars = {author: {name: name, yob: parseInt(yob)}};
    console.log('creating author...');

    var create = graph(q);

    create(vars).then(function (r) {
        author = r.Author;
        $.notify(`Author created with id ${author.id}`, {position: "top center", autoHideDelay: 3000});

        $("#author_id").val(author.id);

        $("#btnSubmit").removeAttr('disabled');
        $("#btnDelete").removeAttr('disabled');

        authorList();
    }).catch(function (error) {
        alert(JSON.stringify(error))
    })
}

function updateAuthor(id, name, yob) {
    var q = `mutation UpdateAuthor($author: AuthorInput) {UpdateAuthor(author: $author) {id}}`;
    var vars = {author: {id: id, name: name, yob: parseInt(yob)}};
    console.log(`updating author ${id}...`);

    var update = graph(q);

    update(vars).then(function (r) {
        author = r.UpdateAuthor;
        $.notify(`Author updated`, {position: "top center", autoHideDelay: 3000});

        $("#btnSubmit").removeAttr('disabled');
        $("#btnDelete").removeAttr('disabled');

        authorList();
    }).catch(function (error) {
        alert(JSON.stringify(error))
    })
}

function deleteAuthor(id) {
    var q = `mutation DeleteAuthor($id: ID) {DeleteAuthor(id: $id)}`;
    var vars = {id: id};
    console.log(`deleting author ${id}...`);

    var del = graph(q);

    del(vars).then(function (r) {
        $.notify(`Author ${id} deleted.`, {position: "top center", autoHideDelay: 3000});

        $('#author_id').val(null);
        $('#name').val(null);
        $('#yob').val(null);

        authorList();
    }).catch(function (error) {
        alert(JSON.stringify(error))
    })
}

function authorList() {
    $("#all > tbody").html("");

    var q = `{
        Authors {
          id
          name
          yob
          created_at
          updated_at
          books {
            id
          }
       }
    }`;

    console.log('loading authors...');

    graph.query.run(q).then(function (all) {
        all.Authors.forEach(function (r) {
            $('#all tbody').append(`<tr data-id="${r.id}"><th scope="row">${r.id}</th>
                    <td>${r.name}</td>
                    <td>${r.yob}</td>
                    <td>${r.created_at}</td>
                    <td>${r.updated_at}</td>
                    <td><a href="books.html?author_id=${r.id}">${r.books.length}</a></td></tr>`);
        });

    }).catch(function (error) {
        alert(JSON.stringify(error));
    })
}


function run() {
    console.log('starting...');

    authorList();
}