if Meteor.isServer
  # Create a batch to test the lobby on
  batchId = "lobbyBatchTest"
  Batches.upsert batchId, $set: {}

  lobby = TurkServer.getBatch(batchId).lobby

  Meteor.methods
    joinLobby: ->
      lobby.addUser Meteor.userId()
    getLobby: ->
      lobby.getUsers()
    leaveLobby: ->
      lobby.removeUser Meteor.userId()

if Meteor.isClient
  Tinytest.addAsync "lobby - verify config", (test, next) ->
    groupSize = null

    verify = ->
      test.isTrue groupSize
      test.equal groupSize.value, 3
      next()

    fail = ->
      test.fail()
      next()

    simplePoll (-> (groupSize = TSConfig.findOne("lobbyThreshold"))? ), verify, fail, 2000

  # Basic tests just to make sure joining/leaving works as intended
  Tinytest.addAsync "lobby - user join", (test, next) ->
    Meteor.call "joinLobby", (err, res) ->
      test.isFalse err
      next()

  Tinytest.addAsync "lobby - check contents", (test, next) ->
    Meteor.call "getLobby", (err, res) ->
      test.isFalse err
      test.length res, 1
      test.equal res[0]._id, Meteor.userId()
      test.equal res[0].status, false
      next()

  Tinytest.addAsync "lobby - user leave", (test, next) ->
    Meteor.call "leaveLobby", (err, res) ->
      test.isFalse err
      next()
