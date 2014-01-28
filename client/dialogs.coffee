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
  "submit form": (e, tmpl) ->
    e.preventDefault()
    username = tmpl.find("input[name=username]").value
    Meteor.call "ts-set-username", username, (err, res) ->
      bootbox.alert(err.reason) if err
