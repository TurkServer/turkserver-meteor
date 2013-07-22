UserStatus.on "sessionLogin", (userId, sessionId, ipAddr) ->


UserStatus.on "sessionLogout", (userId, sessionId, ipAddr) ->
  # TODO track inactivity
