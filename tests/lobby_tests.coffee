if Meteor.isServer
  Meteor.methods
    setupLobby: -> Batches.insert
      lobby: true
      active: true
      grouping: "groupSize"
      groupVal: 3
    joinLobby: ->
      TurkServer.Lobby.addUser Meteor.userId()
    getLobby: ->
      LobbyStatus.find().fetch()
    leaveLobby: ->
      TurkServer.Lobby.removeUser Meteor.userId()
    teardownLobby: ->
      Batches.remove(active: true)

if Meteor.isClient

  Tinytest.addAsync "lobby - set up", (test, next) ->
    Meteor.call "setupLobby", next

  Tinytest.addAsync "lobby - verify config", (test, next) ->
    Deps.autorun (c) ->
      groupSize = TSConfig.findOne("lobbyThreshold")
      return unless groupSize?

      c.stop()
      test.isTrue groupSize
      test.equal groupSize.value, 3
      next()

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

  Tinytest.addAsync "lobby - tear down", (test, next) ->
    Meteor.call "teardownLobby", (err, res) ->
      test.isFalse err
      next()
