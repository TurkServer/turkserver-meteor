
var both = ['client', 'server'];

Package.on_use(function (api) {
    api.use([
        'bootstrap',
        'session',
        'handlebars',
        'templating'
    ], 'client');

    api.use([
        'accounts-base',
        'deps',
        'stylus',
        'coffeescript'
    ], both);

    api.use('user-status', 'server');

    // Shared files
    api.add_files([
        'lobby.coffee'
    ], both);

    // Client
    api.add_files([
        'lobby_client.html',
        'lobby_client.coffee'
    ], 'client');
});

Package.on_test(function (api) {

});
