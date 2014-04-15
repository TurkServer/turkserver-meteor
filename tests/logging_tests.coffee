# Server methods
if Meteor.isServer

  Meteor.methods
    # Clear anything in logs for the given group
    clearLogs: ->
      Partitioner.group()
      Logs.remove
        _groupId: Partitioner.group()
      return
    getLogs: (selector) ->
      return Logs.find(selector || {}).fetch()

  Tinytest.addAsync "logging - server group binding", (test, next) ->
    Partitioner.bindGroup "poop", ->
      Meteor.call "clearLogs"
      TurkServer.log
        boo: "hoo"

    doc = Logs.findOne(boo: "hoo")

    test.equal doc.boo, "hoo"
    test.isTrue doc._groupId
    test.isTrue doc._timestamp
    next()

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
      Meteor.call "getLogs", {foo: "bar"}, expect (err, res) ->
        test.isFalse err
        test.length res, 1

        logItem = res[0]

        test.isTrue logItem.foo
        test.isTrue logItem._userId
        test.isTrue logItem._groupId
        test.isTrue logItem._timestamp
  ]
