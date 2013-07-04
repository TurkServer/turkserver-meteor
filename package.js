Package.describe({
    summary: "Online experimental framework built with Meteor"
});

Npm.depends({
    mturk: "0.4.1"
});

var both = ['client', 'server'];

Package.on_use(function (api) {
    api.use('bootstrap', 'client');
    api.use('coffeescript', 'server');
    api.use('templating', 'client');

    // TODO add an explicit dependency for this
    api.use('user-status', 'server');

    // Server files
    api.add_files([
        'lib/turkserver.coffee'
    ], 'server');
});

Package.on_test(function (api) {

});
