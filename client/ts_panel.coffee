
Template.turkserverPulldown.events =
  "click .ts-adminToggle": (e) ->
    e.preventDefault()
    $("#ts-content").slideToggle()

adminSubscription = null

# TODO make this login a bit more secure
Deps.autorun ->
  if Session.equals("admin", true)
    adminSubscription = Meteor.subscribe("tsAdmin")
  else
    adminSubscription?.stop()
