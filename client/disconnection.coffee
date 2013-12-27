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
