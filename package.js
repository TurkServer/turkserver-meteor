Package.describe({
    summary: "Online experimental framework built with Meteor"
});

Npm.depends({
    // mturk: "./mturk", // https://github.com/meteor/meteor/issues/1810
    // Currently using a fork in submodule; dependencies below
    // "crypto": "0.0.3",
    "request": "2.30.0",
    "libxmljs": "0.8.1",
    "validator": "2.0.0",
    "querystring": "0.2.0",
    "async": "0.2.10",
    // End mturk dependencies
    deepmerge: "0.2.7" // For merging config parameters
});

Package.on_use(function (api) {
    // Client-only deps
    api.use([
        'session',
        'handlebars',
        'templating',
        'd3'
    ], 'client');

    // Client & Server deps
    api.use([
        'accounts-base',
        'accounts-ui',
        'accounts-password', // for the admin user
        'deps',
        'stylus',
        'jquery',
        'underscore',
        'coffeescript',
        'facts'
    ]);

    // Non-core packages
    api.use('bootstrap-3');
    api.use('bootboxjs');
    api.use('x-editable-bootstrap');
    api.use('iron-router');
    api.use('moment');

    api.use('collection-hooks');
    api.use('partitioner');
    api.use('timesync');
    api.use('user-status');

    // mturk fork
    api.add_files([
      'mturk/index.js'
    ], 'server');

    // Shared files
    api.add_files([
        'lib/common.coffee'
    ]);

    // Server files
    api.add_files([
        'lib/config.coffee',
        'lib/turkserver.coffee',
        'lib/mturk.coffee',
        'lib/experiments.coffee',
        'lib/logging.coffee',
        'lib/assigners.coffee',
        'lib/connections.coffee',
        'lib/timers.coffee',
        'lib/accounts_mturk.coffee',
        'lib/lobby_server.coffee'
    ], 'server');

    // Client
    api.add_files([
        'client/templates.html',
        'client/ts_client.styl',
        'client/ts_client.coffee',
        'client/logging_client.coffee',
        'client/timers_client.coffee',
        'client/helpers.coffee',
        'client/lobby_client.html',
        'client/lobby_client.coffee',
        'client/dialogs.coffee'
    ], 'client');

    // Admin
    api.add_files([
        'admin/admin.styl',
        'admin/util.html',
        'admin/util.coffee',
        'admin/clientAdmin.html',
        'admin/clientAdmin.coffee',
        'admin/mturkAdmin.html',
        'admin/mturkAdmin.coffee',
        'admin/experimentAdmin.html',
        'admin/experimentAdmin.coffee',
        'admin/lobbyAdmin.html',
        'admin/lobbyAdmin.coffee'
    ], 'client');

    api.add_files('admin/admin.coffee', 'server');

    api.export(['TurkServer']);
});

Package.on_test(function (api) {
    api.use('turkserver');

    api.use([
      'accounts-base',
      'accounts-password',
      'deps',
      'coffeescript'
    ]);

    api.use('partitioner');
    api.use('iron-router'); // Needed so we can un-configure the router

    api.use([
      'tinytest',
      'test-helpers'
    ]);

    api.use('session', 'client');

    api.add_files("tests/insecure_login.js");

    api.add_files('tests/utils.coffee');

    api.add_files('tests/lobby_tests.coffee');
    api.add_files('tests/auth_tests.coffee', 'server');
    api.add_files('tests/experiment_tests.coffee');
    api.add_files('tests/logging_tests.coffee');
});
