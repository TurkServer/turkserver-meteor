Package.describe({
  name: "mizzao:turkserver",
  summary: "Web-based, real-time behavioral studies and experiments",
  version: "0.5.0",
  git: "https://github.com/TurkServer/turkserver-meteor.git"
});

Npm.depends({
  "mturk-api": "1.3.2",
  jspath: "0.3.2",
  deepmerge: "0.2.7" // For merging config parameters
});

Package.onUse(function (api) {
  api.versionsFrom("1.2.0.1");

  // Client-only deps
  api.use([
    'session',
    'ui',
    'templating',
    'reactive-var'
  ], 'client');

  // Client & Server deps
  api.use([
    'accounts-base',
    'accounts-ui',
    'accounts-password', // for the admin user
    'check',
    'deps',
    'ejson',
    'jquery',
    'random',
    'underscore',
    'coffeescript',
    'ecmascript',
    'facts'
  ]);

  api.use(["ddp", "mongo"]); // For pub/sub and collections

  // To use the promises in mturk-api from Fibers code
  api.use("promise");

  // Non-core packages
  api.use("aldeed:template-extension@3.4.3");

  api.use("mizzao:bootboxjs@4.4.0");
  api.use("iron:router@1.0.11");
  api.use("iron:middleware-stack@1.1.0"); // Fixes route error in Chrome 51+
  api.use("momentjs:moment@2.10.6");
  api.use("twbs:bootstrap@3.3.5");
  api.use("d3js:d3@3.5.5");

  api.use("mizzao:autocomplete@0.5.1");
  api.use('natestrauser:x-editable-bootstrap@1.5.2_1');

  // Dev packages - may be locally installed with submodule
  api.use("matb33:collection-hooks@0.7.15");
  api.use("mizzao:partitioner@0.5.9");
  api.use('mizzao:timesync@0.3.3');
  api.use("mizzao:user-status@0.6.5");

  // Shared files
  api.addFiles([
    'lib/common.js',
    'lib/common.coffee',
    'lib/util.coffee'
  ]);

  // Server files
  api.addFiles([
    'server/config.js',
    'server/turkserver.coffee',
    'server/server_api.js',
    'server/mturk.js',
    'server/lobby_server.coffee',
    'server/batches.coffee',
    'server/instance.js',
    'server/logging.coffee',
    'server/assigners.js',
    'server/assigners_extra.js',
    'server/assignment.js',
    'server/connections.coffee',
    'server/timers_server.js',
    'server/accounts_mturk.coffee'
  ], 'server');

  // Client
  api.addFiles([
    'client/templates.html',
    'client/login.html',
    'client/client_api.js',
    'client/ts_client.css',
    'client/ts_client.coffee',
    'client/login.coffee',
    'client/logging_client.coffee',
    'client/timers_client.coffee',
    'client/helpers.coffee',
    'client/lobby_client.html',
    'client/lobby_client.coffee',
    'client/dialogs.coffee'
  ], 'client');

  // Admin
  api.addFiles([
    'admin/admin.css',
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

  api.addFiles('admin/admin.coffee', 'server');

  api.export(['TurkServer']);

  /*
    Exported collections for legacy purposes
    TODO Direct access to these should be deprecated in the future
   */
  api.export(['Batches', 'Treatments', 'Experiments', 'LobbyStatus', 'Logs', 'RoundTimers']);

  api.export(['ErrMsg', 'TestUtils'], { testOnly: true });
});

Package.onTest(function (api) {
  api.use([
    'accounts-base',
    'accounts-password',
    'check',
    'deps',
    'coffeescript',
    'mongo',
    'random',
    'ui',
    'underscore'
  ]);

  api.use([
    'tinytest',
    'test-helpers'
  ]);

  api.use('session', 'client');

  api.use('iron:router'); // Needed so we can un-configure the router
  api.use('mizzao:partitioner');
  api.use('mizzao:timesync');

  api.use("mizzao:turkserver"); // This package!

  api.addFiles("tests/display_fix.css");

  api.addFiles('tests/utils.coffee'); // Deletes users so do it before insecure login
  api.addFiles("tests/insecure_login.js");

  api.addFiles('tests/lobby_tests.coffee');
  api.addFiles('tests/admin_tests.coffee', 'server');
  api.addFiles('tests/auth_tests.coffee', 'server');
  api.addFiles('tests/connection_tests.coffee', 'server');
  api.addFiles('tests/experiment_tests.coffee', 'server');
  api.addFiles('tests/experiment_client_tests.coffee');
  api.addFiles('tests/timer_tests.coffee', 'server');
  api.addFiles('tests/logging_tests.coffee');
  // This goes after experiment tests, so we can be sure that assigning works
  api.addFiles('tests/assigner_tests.coffee', 'server');

  // This runs after user is logged in, as it requires a userId
  api.addFiles('tests/helper_tests.coffee');
});
