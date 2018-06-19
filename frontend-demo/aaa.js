var graph = graphql("http://localhost:3000/", {
    headers: {
      'Surikat':  'abc'//Math.random().toString(36).replace(/[^a-z]+/g, '')
    }
});

var current_user;

$("#btnLogin").click(function (el) {
    el.preventDefault();

    $(this).attr('disabled', true);

    var email = $('#email').val();
    var password = $('#password').val();

    authenticate(email, password);
});

$('#btnCurUser').click(function (el) {
    el.preventDefault();

    $(this).attr('disabled', true);
    getCurrentUser();
});

$('#btnLogout').click(function (e) {
    e.preventDefault();

    logout();
});

$('#btnProtected').click(function (e) {
    e.preventDefault();

    demoTwo();
});

function demoTwo() {
    var q = '{DemoTwo}';
    console.log('calling a role-protected method...');

    graph.query.run(q).then(function (r) {
        $.notify(r.DemoTwo, {position: 'top left', autoHideDelay: 3000})
    }).catch(function(error) {
        if (error.find(e => e.accessDenied)) {
            $.notify('Access denied', {position: "top center", autoHideDelay: 3000});
        } else {
            alert(JSON.stringify(error))
        }
    })
}

function logout() {
    var q = '{Logout}';
    console.log('logging out...');

    graph.query.run(q).then(function (r) {
        $.notify('You have been logged out.', {position: "top center", autoHideDelay: 3000});
        $('#not-logged-in').show();
        $('#logged-in').hide();
        $('#btnLogin').removeAttr('disabled');
    }).catch(function(error) {
        alert(JSON.stringify(error))
    })
}

function getCurrentUser() {
    var q = '{CurrentUser {id,email,roleids}}';
    console.log('getting current user...');

    graph.query.run(q).then(function (r) {
        current_user = r.CurrentUser;
        console.log('current user: ', current_user);

        $('#not-logged-in').hide();
        $('#logged-in').show();

        $('#current_user').html(`You are logged in as ${current_user.email}. Your roles are: ${current_user.roleids}`);
        $.notify(`You are logged in as ${current_user.email}. Your roles are: ${current_user.roleids}`, {position: "top center", autoHideDelay: 3000});
        $('#btnCurUser').removeAttr('disabled');
    }).catch(function(error) {
        if (error.find(e => e.accessDenied)) {
            $.notify('Bad credentials', {position: "top center", autoHideDelay: 3000});
        } else {
            alert(JSON.stringify(error))
        }
        alert(JSON.stringify(error))
    })
}

function authenticate(email, password) {
    var q = `{Authenticate(email: "${email}", password: "${password}")}`;
    console.log(`logging in...`);

    graph.query.run(q).then(function (r) {
        $.notify('Successfully authenticated!', {position: "top center", autoHideDelay: 3000});
        $('#not-logged-in').hide();
        $('#logged-in').show();
    }).catch(function (error) {
        if (error.find(e => e.noResult)) {
            $.notify('Bad credentials', {position: "top center", autoHideDelay: 3000});
        } else {
            alert(JSON.stringify(error))
        }
        $('#btnLogin').removeAttr('disabled');
    })
}


function run() {
    console.log('starting...');

    getCurrentUser();
}