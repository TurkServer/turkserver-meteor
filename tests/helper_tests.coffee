# TODO: try implementing Meteor.isServer stuff with setUserId

if Meteor.isClient
  Tinytest.addAsync "helpers - isAdmin", (test, next) ->
    InsecureLogin.ready ->
      test.isFalse TurkServer.isAdmin()
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
