# Server methods
if Meteor.isServer

  # Clear anything in logs
  Meteor.methods
    clearLogs: -> Logs.remove({})
    getLogs: ->
      return Logs.find().fetch()

# Client methods
if Meteor.isClient

  Tinytest.addAsync "logging - initialize test", (test, next) ->
    Meteor.call "clearLogs", (err, res) ->
      test.isFalse err
      next()

  testAsyncMulti "logging - groupId and timestamp", [
    (test, expect) ->
      TurkServer.log {foo: "bar"}, expect (err, res) ->
        test.isFalse err
  ,
    (test, expect) ->
      Meteor.call "getLogs", expect (err, res) ->
        test.isFalse err
        test.length res, 1

        logItem = res[0]

        test.isTrue logItem.foo
        test.isTrue logItem._groupId
        test.isTrue logItem._timestamp
  ]
