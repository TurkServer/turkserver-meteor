/*
 * decaffeinate suggestions:
 * DS102: Remove unnecessary code created because of implicit returns
 * DS103: Rewrite code to no longer use __guard__
 * DS207: Consider shorter variations of null checks
 * Full docs: https://github.com/decaffeinate/decaffeinate/blob/master/docs/suggestions.md
 */
/*
  Dialogs to possibly show after page loaded
*/

/*
  Disconnect warning

  Don't display this warning until some time after app has started; otherwise
  it's confusing to users
*/
const disconnectWarningDelay = 5000;

TurkServer._delayedStartup(function() {
  let disconnectDialog = null;

  // Warn when disconnected instead of just sitting there.
  return Deps.autorun(function() {
    const status = Meteor.status();

    if (status.connected && (disconnectDialog != null)) {
      disconnectDialog.modal("hide");
      disconnectDialog = null;
      return;
    }

    if (!status.connected && (disconnectDialog === null)) {
      disconnectDialog = bootbox.dialog({
        closeButton: false,
        message:
          `<h3>You have been disconnected from the server.
Please check your Internet connection.</h3>`
      });
      return;
    }
  });
}
, disconnectWarningDelay);

TurkServer._displayModal = function(template, data, options) {
  // minimum options to get message to show
  if (options == null) { options = { message: " " }; }
  const dialog = bootbox.dialog(options);
  // Take out the thing that bootbox rendered
  dialog.find(".bootbox-body").remove();

  // Since bootbox/bootstrap uses jQuery, this should clean up itself
  Blaze.renderWithData(template, data, dialog.find(".modal-body")[0]);
  return dialog;
};

TurkServer.ensureUsername = function() {
  /*
    Capture username after logging in
  */
  let usernameDialog = null;

  return Deps.autorun(function() {
    const userId = Meteor.userId();
    if (!userId) {
      if (usernameDialog != null) {
        usernameDialog.modal("hide");
      }
      usernameDialog = null;
      return;
    }

    // TODO: stop the username dialog popping up during the subscription process
    const username = __guard__(Meteor.users.findOne(userId, {fields: {username: 1}}), x => x.username);

    if (username && usernameDialog) {
      usernameDialog.modal("hide");
      usernameDialog = null;
      return;
    }

    if (!username && (usernameDialog === null)) {
      usernameDialog = bootbox.dialog({message: " "}).html('');
      Blaze.render(Template.tsRequestUsername, usernameDialog[0]);
      return;
    }
  });
};

Template.tsRequestUsername.events = {
  "focus input"() { return Session.set("_tsUsernameError", undefined); },
  "submit form"(e, tmpl) {
    e.preventDefault();
    const input = tmpl.find("input[name=username]");
    input.blur();
    const username = input.value;
    return Meteor.call("ts-set-username", username, function(err, res) {
      if (err) { return Session.set("_tsUsernameError", err.reason); }
    });
  }
};

Template.tsRequestUsername.helpers({
  usernameError() { return Session.get("_tsUsernameError"); }});

function __guard__(value, transform) {
  return (typeof value !== 'undefined' && value !== null) ? transform(value) : undefined;
}