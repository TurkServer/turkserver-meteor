Package.describe({
    summary: "Online experimental framework built with Meteor"
});

Npm.depends({
    mturk: "0.4.1"
});

var both = ['client', 'server'];

Package.on_use(function (api) {
    api.use(['bootstrap', 'templating'], 'client');

    api.use(['accounts-base', 'stylus', 'coffeescript'], 'server');

    api.use('user-status', 'server');

    // Shared files
    api.add_files([
        'lib/common.coffee',
        'lib/grouping.coffee'
    ], both)

    // Client
    api.add_files([
        'client/ts_client.styl',

        'client/ts_panel.html',

        'client/ts_panel.coffee',
        'client/ts_client.coffee'
    ], 'client');


    // Server files
    api.add_files([
        'lib/turkserver.coffee',
        'lib/connections.coffee',
        'lib/admin.coffee',
        'lib/accounts_mturk.coffee'
    ], 'server');

});

Package.on_test(function (api) {
    api.use('turkserver', both);
    api.use('test-helpers', both);
    api.use('tinytest', both);

    api.use('accounts-testing', both);
    api.use('session', 'client');

    // api.add_files('tests/router_client_tests.js', 'client');

//    api.use('http', 'server');
    api.add_files('tests/authentication_tests.coffee', 'server');
    api.add_files('tests/grouping_tests.coffee', both);
//
//    api.add_files('tests/router_common_tests.js', ['client', 'server']);
});
