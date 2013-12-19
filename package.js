Package.describe({
    summary: "Online experimental framework built with Meteor"
});

Npm.depends({
    mturk: "0.4.1"
});

Package.on_use(function (api) {
    // Client-only deps
    api.use([
        'bootstrap',
        'session',
        'handlebars',
        'templating'
    ], 'client');

    // Client & Server deps
    api.use([
        'accounts-base',
        'accounts-ui',
        'accounts-password', // for the admin user
        'deps',
        'stylus',
        'coffeescript'
    ]);

    // Non-core packages
    api.use('bootboxjs');
    api.use('collection-hooks');
    api.use('user-status', 'server');
    api.use('iron-router', { weak: true }); // We like Iron Router but no need to force it

    // Shared files
    api.add_files([
        'lib/common.coffee',
        'lib/grouping.coffee'
    ]);

    // Server files
    api.add_files([
        'lib/turkserver.coffee',
        'lib/connections.coffee',
        'lib/accounts_mturk.coffee'
    ], 'server');

    // Client
    api.add_files([
        'client/helpers.coffee',
        'client/ts_client.styl',
        'client/ts_client.html',
        'client/ts_client.coffee'
    ], 'client');

    // Admin
    api.add_files([
        'admin/clientAdmin.html',
        'admin/clientAdmin.coffee',
        'admin/experimentAdmin.html',
        'admin/experimentAdmin.coffee',
        'admin/lobbyAdmin.html',
        'admin/lobbyAdmin.coffee'
    ], 'client');

    api.add_files('admin/admin.coffee', 'server');

    // Lobby
    api.add_files([
        'lobby/lobby.coffee'
    ]);

    api.add_files([
        'lobby/lobby_client.html',
        'lobby/lobby_client.coffee'
    ], 'client');

});

Package.on_test(function (api) {
    api.use('turkserver');

    api.use([
      'accounts-base',
      'accounts-password',
      'deps',
      'coffeescript'
    ]);
    api.use([
      'tinytest',
      'test-helpers'
    ]);

    api.use('session', 'client');

    api.add_files("tests/insecure_login.js");

    api.add_files('tests/browser_tests.coffee', 'client');
    api.add_files('tests/authentication_tests.coffee', 'server');
    api.add_files('tests/grouping_tests.coffee');
});
