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

  # Create a dummy assignment
  userId = "expUser"
  workerId = "expWorker"

  Tinytest.addAsync "experiment - init - setup test", (test, next) ->
    TurkServer.directOperation ->
      # initial cleanup for this test
      Doobie.remove {}

    Experiments.remove "fooGroup"
    Treatments.remove(name: "fooTreatment")
    TurkServer.Groups.clearUserGroup(userId)
    Meteor.users.upsert { _id: userId },
        $set: workerId: workerId

    Assignments.upsert {
        hitId: "expHIT"
        assignmentId: "expAsst"
        workerId: workerId
      }, {
        $set: status: "assigned"
        $unset: experimentId: null
      }

    treatment = undefined
    group = undefined
    Treatments.insert(name: "fooTreatment")
    TurkServer.Experiment.create("fooTreatment", _id: "fooGroup")
    TurkServer.Experiment.setup("fooGroup")
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

  Tinytest.addAsync "experiment - addUser - records experiment ID", (test, next) ->
    TurkServer.Experiment.addUser("fooGroup", userId)
    asst = Assignments.findOne(workerId: workerId, status: "assigned")
    test.equal asst.experimentId, "fooGroup"
    next()

  # TODO clean up assignments if they affect other tests
