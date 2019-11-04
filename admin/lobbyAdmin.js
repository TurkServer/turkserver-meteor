/*
 * decaffeinate suggestions:
 * DS102: Remove unnecessary code created because of implicit returns
 * Full docs: https://github.com/decaffeinate/decaffeinate/blob/master/docs/suggestions.md
 */
Template.tsAdminLobby.helpers({
  lobbyUsers() { return LobbyStatus.find(); }});

Template.tsAdminLobbyHeader.events = {
  "submit form"(e, t) {
    e.preventDefault();
    const event = t.$("input[name=lobby-event]").val();
    return Meteor.call("ts-admin-lobby-event", Session.get("_tsViewingBatchId"), event, function(err, res) {
      if (err) { return bootbox.alert(err); }
    });
  }
};

Template.tsAdminLobbyHeader.helpers({
  count() { return LobbyStatus.find().count(); },
  readyCount() { return LobbyStatus.find({status: true}).count(); }
});
