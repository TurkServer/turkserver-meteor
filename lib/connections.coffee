UserStatus.on "sessionLogin", (userId, sessionId, ipAddr) ->


UserStatus.on "sessionLogout", (userId, sessionId, ipAddr) ->


Meteor.methods
  "inactive": (data) ->
    # TODO implement tracking inactivity
    # We don't trust client timestamps, but only as identifier and use difference
    console.log data.start, data.time
