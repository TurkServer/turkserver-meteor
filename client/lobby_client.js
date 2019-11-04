/*
 * decaffeinate suggestions:
 * DS102: Remove unnecessary code created because of implicit returns
 * DS103: Rewrite code to no longer use __guard__
 * DS207: Consider shorter variations of null checks
 * Full docs: https://github.com/decaffeinate/decaffeinate/blob/master/docs/suggestions.md
 */
/*
  Set up route and auto-redirection for default lobby, unless disabled

  As defined below, autoLobby is default true unless explicitly set to false
  TODO document this setting
*/
if (__guard__(__guard__(Meteor.settings != null ? Meteor.settings.public : undefined, x1 => x1.turkserver), x => x.autoLobby) !== false) {
  Router.map(function() {
    return this.route("lobby", {
      template: "tsBasicLobby",
      layoutTemplate: "tsContainer",
      onBeforeAction() {
        // Don't show lobby template to unauthenticated users
        if (!Meteor.user()) {
          this.layout("tsContainer");
          return this.render("tsUserAccessDenied");
        } else {
          return this.next();
        }
      }
    }
    );
  });

  // We need to defer this because iron router can throw errors if a route is
  // hit before the page is fully loaded
  Meteor.startup(() => Meteor.defer(() => // Subscribe to lobby if we are in it (auto unsubscribe if we aren't)
  Deps.autorun(function() {
    if (typeof Package !== 'undefined' && Package !== null ? Package.tinytest : undefined) { return; } // Don't change routes when being tested
    if (TurkServer.inLobby()) {
      Meteor.subscribe("lobby", __guard__(TurkServer.batch(), x2 => x2._id));
      return Router.go("/lobby");
    }
  })));
}

Meteor.methods({
  "toggleStatus"() {
    let existing;
    const userId = Meteor.userId();
    if (userId) { existing = LobbyStatus.findOne(userId); }
    if (!userId || !existing) { return; }
    
    return LobbyStatus.update(userId,
      {$set: { status: !existing.status }});
  }});

Template.tsBasicLobby.helpers({
  count() { return LobbyStatus.find().count(); },
  lobbyInfo() { return LobbyStatus.find(); },
  identifier() { return __guard__(Meteor.users.findOne(this._id), x2 => x2.username) || "<i>unnamed user</i>"; }
});

Template.tsLobby.helpers({
  lobbyInfo() { return LobbyStatus.find(); },
  identifier() { return __guard__(Meteor.users.findOne(this._id), x2 => x2.username) || this._id; },
  readyEnabled() {
    return (LobbyStatus.find().count() >= TSConfig.findOne("lobbyThreshold").value) && (this._id === Meteor.userId());
  }
});

Template.tsLobby.events = {
  "click a.changeStatus"(ev) {
    ev.preventDefault();

    return Meteor.call("toggleStatus", function(err, res) {
      if (err) { return bootbox.alert(err.reason); }
    });
  }
};

function __guard__(value, transform) {
  return (typeof value !== 'undefined' && value !== null) ? transform(value) : undefined;
}