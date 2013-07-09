
getURLParams = ->
  params = {}
  m = window.location.href.match(/[\\?&]([^=]+)=([^&#]*)/g)
  if m
    i = 0

    while i < m.length
      a = m[i].match(/.([^=]+)=(.*)/)
      params[@unescapeURL(a[1])] = @unescapeURL(a[2])
      i++
  return params

mturkLogin = (hitId, assignmentId, workerId, callback) ->
  Accounts.callLoginMethod
    methodArguments: [{
      hitId: hitId
      assignmentId: assignmentId
      workerId: workerId
    }],
    userCallback: callback

Meteor.startup ->
  params = getURLParams()
  return unless params.hitId and params.assignmentId and params.workerId
  mturkLogin(hitId, assignmentId, workerId)

