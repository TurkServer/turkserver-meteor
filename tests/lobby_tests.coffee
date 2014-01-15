if Meteor.isServer
  Meteor.methods
    setupLobby: -> Batches.insert
      lobby: true
      active: true
      grouping: "groupSize"
      groupVal: 3
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

  Tinytest.addAsync "lobby - tear down", (test, next) ->
    Meteor.call "teardownLobby", next
