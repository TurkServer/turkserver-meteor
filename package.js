Package.describe({
    summary: "Online experimental framework built with Meteor"
});

Npm.depends({
    mturk: "0.4.1"
});

var both = ['client', 'server'];

Package.on_use(function (api) {
    api.use('bootstrap', 'client');
    api.use('templating', 'client');

    api.use('stylus', 'server');
    api.use('coffeescript', 'server');

    // TODO add an explicit dependency for this
    api.use('user-status', 'server');

    // Client
    api.add_files([
        'client/tsClient.styl',

        'client/tsPanel.html',

        'client/tsPanel.coffee'
    ], 'client');

    // Server files
    api.add_files([
        'lib/turkserver.coffee'
    ], 'server');
});

Package.on_test(function (api) {
    api.use('turkserver', both);
    api.use('test-helpers', both);
    api.use('tinytest', both);

    api.use('session', 'client');
    // api.add_files('tests/router_client_tests.js', 'client');

//    api.use('http', 'server');
//    api.add_files('tests/router_server_tests.js', 'server');
//
//    api.add_files('tests/router_common_tests.js', ['client', 'server']);
});
