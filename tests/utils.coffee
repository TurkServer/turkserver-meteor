
if Meteor.isClient
  # Prevent router from complaining about missing path
  Router.map ->
    @route "/",
      onBeforeAction: (pause) -> pause()

if Meteor.isServer
  # Set up a dummy batch
  unless Batches.findOne(active: true)
    Batches.insert(active: true)
