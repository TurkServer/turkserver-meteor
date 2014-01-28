###
  Disconnect warning
###
disconnectDialog = null

# Warn when disconnected instead of just sitting there.
Deps.autorun ->
  status = Meteor.status()

  if status.connected and disconnectDialog?
    disconnectDialog.modal("hide")
    disconnectDialog = null
    return

  if !status.connected and disconnectDialog is null
    disconnectDialog = bootbox.dialog(
      """<h3>You have been disconnected from the server.
          Please check your Internet connection.</h3>""")
    return

###
  Capture username after logging in
###
# TODO only do this for experiments that require it
usernameDialog = null

Deps.autorun ->
  userId = Meteor.userId()
  unless userId
    usernameDialog?.modal("hide")
    usernameDialog = null
    return

  username = Meteor.users.findOne(userId, fields: {username: 1})?.username

  if username and usernameDialog
    usernameDialog.modal("hide")
    usernameDialog = null
    return

  if !username and usernameDialog is null
    usernameDialog = bootbox.dialog Meteor.render ->
      Template.tsRequestUsername()
    return

Template.tsRequestUsername.events =
  "focus input": -> Session.set("_tsUsernameError", undefined)
  "submit form": (e, tmpl) ->
    e.preventDefault()
    input = tmpl.find("input[name=username]")
    input.blur()
    username = input.value
    Meteor.call "ts-set-username", username, (err, res) ->
      Session.set("_tsUsernameError", err.reason) if err

Template.tsRequestUsername.usernameError = -> Session.get("_tsUsernameError")
