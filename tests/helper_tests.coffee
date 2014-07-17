# TODO: try implementing Meteor.isServer stuff with setUserId

if Meteor.isClient
  Tinytest.addAsync "helpers - isAdmin", (test, next) ->
    InsecureLogin.ready ->
      # this should be straight up false - isFalse might take `undefined` for an answer.
      test.equal TurkServer.isAdmin(), false
      next()

  Tinytest.addAsync "helpers - checkAdmin", (test, next) ->
    test.throws ->
      TurkServer.checkAdmin()
    , (e) -> e.error is 403 and e.reason is ErrMsg.notAdminErr
    next()

  Tinytest.addAsync "helpers - checkNotAdmin", (test, next) ->
    TurkServer.checkNotAdmin()
    test.ok()
    next()

###
  Timer helper tests - server/client
###
Tinytest.add "timers - formatMillis renders 0 properly", (test) ->
  test.equal TurkServer.Util.formatMillis(0), "0:00:00"

Tinytest.add "timers - formatMillis renders negative values properly", (test) ->
  test.equal TurkServer.Util.formatMillis(-1000), "-0:00:01"
