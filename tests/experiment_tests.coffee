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

    # Test deferred insert
    Meteor.defer ->
      Doobie.insert
        bar: "baz"

  TurkServer.partitionCollection Doobie

  TurkServer.initialize contextHandler
  TurkServer.initialize insertHandler

  Tinytest.addAsync "experiment - init - setup test", (test, next) ->
    TurkServer.directOperation -> Doobie.remove {}
    treatment = undefined
    group = undefined

    TurkServer.Experiment.setup("fooGroup", "fooTreatment")
    next()

  Tinytest.addAsync "experiment - init - context", (test, next) ->
    test.equal treatment, "fooTreatment"
    test.equal group, "fooGroup"
    next()

  Tinytest.addAsync "experiment - init - global group", (test, next) ->
    stuff = TurkServer.directOperation -> Doobie.find().fetch()
    test.length stuff, 2

    test.equal stuff[0].foo, "bar"
    test.equal stuff[0]._groupId, "fooGroup"

    test.equal stuff[1].bar, "baz"
    test.equal stuff[1]._groupId, "fooGroup"
    next()
