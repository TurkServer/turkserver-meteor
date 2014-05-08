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

  Partitioner.partitionCollection Doobie

  TurkServer.initialize contextHandler
  TurkServer.initialize insertHandler

  # Create a dummy assignment
  userId = "expUser"
  workerId = "expWorker"
  Meteor.users.upsert { _id: userId },
    $set: workerId: workerId

  # Set up a treatment for testing
  Treatments.upsert {name: "fooTreatment"},
    $set:
      fooProperty: "bar"

  Tinytest.addAsync "experiment - instance - setup test", (test, next) ->
    Partitioner.directOperation ->
      # initial cleanup for this test
      Doobie.remove {}

    Experiments.remove "fooGroup"
    Partitioner.clearUserGroup(userId)

    Assignments.upsert {
        hitId: "expHIT"
        assignmentId: "expAsst"
        workerId: workerId
      }, {
        $set: status: "assigned"
        $unset: experimentId: null
      }

    instance = TurkServer.Experiment.createInstance({}, [ "fooTreatment" ], {_id: "fooGroup"})
    test.isTrue(instance instanceof TurkServer.Instance)
    next()

  Tinytest.addAsync "experiment - instance - init context", (test, next) ->
    treatment = undefined
    group = undefined
    instance = TurkServer.Experiment.getInstance("fooGroup")
    instance.setup()

    # TODO check instance batch

    test.isTrue treatment
    test.equal treatment[0].name, "fooTreatment"
    test.equal treatment[0].fooProperty, "bar"
    test.equal group, "fooGroup"
    next()

  Tinytest.addAsync "experiment - instance - global group", (test, next) ->
    stuff = Partitioner.directOperation ->
      Doobie.find().fetch()

    test.length stuff, 2

    test.equal stuff[0].foo, "bar"
    test.equal stuff[0]._groupId, "fooGroup"

    test.equal stuff[1].bar, "baz"
    test.equal stuff[1]._groupId, "fooGroup"
    next()

  Tinytest.addAsync "experiment - instance - addUser records experiment ID", (test, next) ->
    instance = TurkServer.Experiment.getInstance("fooGroup")
    instance.addUser(userId)

    user = Meteor.users.findOne(userId)
    asst = Assignments.findOne(workerId: workerId, status: "assigned")

    test.isTrue userId in instance.users()
    test.equal user.turkserver.state, "experiment"
    test.isTrue("fooGroup" in asst.instances)

    next()

  # TODO clean up assignments if they affect other tests

  Tinytest.addAsync "experiment - instance - throws error if doesn't exist", (test, next) ->
    test.throws ->
      TurkServer.Experiment.getInstance("yabbadabbadoober")
    next()

  # Add a user to this group upon login, for client tests below
  Accounts.onLogin (info) ->
    userId = info.user._id
    Partitioner.clearUserGroup(userId)
    TurkServer.Experiment.getInstance("fooGroup").addUser(userId)

if Meteor.isClient
  Tinytest.addAsync "experiment - client - received experiment and treatment", (test, next) ->
    Deps.autorun (c) ->
      treatment = TurkServer.treatment()
      console.info "Got treatment ", treatment

      if treatment
        c.stop()
        test.isTrue Experiments.findOne()
        test.isTrue treatment

        # No _id or name sent over the wire
        test.isFalse treatment._id
        test.isFalse treatment.name
        test.equal treatment.fooProperty, "bar"
        next()
