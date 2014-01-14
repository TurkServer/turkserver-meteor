if Meteor.isServer

  Doobie = new Meteor.Collection("experiment_test")

  treatment = undefined
  group = undefined

  contextHandler = ->
    treatment = @treatment
    group = @group

  insertHandler = ->
    Doobie.insert
      foo: "bar"

  TurkServer.registerCollection Doobie

  TurkServer.initialize contextHandler
  TurkServer.initialize insertHandler

  Tinytest.add "experiment - init - setup test", (test) ->
    Doobie.remove { _direct: true }
    treatment = undefined
    group = undefined

    TurkServer.setupExperiment("fooGroup", "fooTreatment")
    test.ok()

  Tinytest.add "experiment - init - context", (test) ->
    test.equal treatment, "fooTreatment"
    test.equal group, "fooGroup"

  Tinytest.add "experiment - init - global group", (test) ->
    stuff = Doobie.find( _direct: true ).fetch()
    test.length stuff, 1
    test.equal stuff[0].foo, "bar"
    test.equal stuff[0]._groupId, "fooGroup"


