testGroup = "timerTest"

# use a before here because tests are async
withCleanup = TestUtils.getCleanupWrapper
  before: ->
    # Clear any timer information
    Partitioner.bindGroup testGroup, ->
      RoundTimers.remove {}
    # Clear any handlers
    TestUtils.clearRoundHandlers()

Tinytest.addAsync "timers - expiration callback", withCleanup (test, next) ->
  Partitioner.bindGroup testGroup, ->
    now = new Date

    TurkServer.Timers.onRoundEnd (type) ->
      test.equal(type, TurkServer.Timers.ROUND_END_TIMEOUT)
      # Cancel group binding
      Partitioner._currentGroup.withValue(null, next)

    TurkServer.Timers.startNewRound now, new Date(now.getTime() + 100)

Tinytest.addAsync "timers - start multiple rounds", withCleanup (test, next) ->
  Partitioner.bindGroup testGroup, ->
    now = new Date

    TurkServer.Timers.onRoundEnd (type) ->
      test.equal(type, TurkServer.Timers.ROUND_END_NEWROUND)

      Partitioner._currentGroup.withValue(null, next)

    TurkServer.Timers.startNewRound now, new Date(now.getTime() + 100)
    TurkServer.Timers.startNewRound now, new Date(now.getTime() + 100)

Tinytest.addAsync "timers - early expiration", withCleanup (test, next) ->
  Partitioner.bindGroup testGroup, ->
    now = new Date

    count = 0
    types = {}

    TurkServer.Timers.onRoundEnd (type) ->
      count++
      types[type] ?= 0
      types[type]++

    TurkServer.Timers.startNewRound now, new Date(now.getTime() + 100)

    TurkServer.Timers.endCurrentRound()

    # round end callback should only have been called once
    Meteor.setTimeout ->
      test.equal(count, 1)
      test.equal(types[TurkServer.Timers.ROUND_END_MANUAL], 1)
      # Cancel group binding
      Partitioner._currentGroup.withValue(null, next)
    , 150

Tinytest.addAsync "timers - robustness to multiple calls", withCleanup (test, next) ->
  Partitioner.bindGroup testGroup, ->

    now = new Date
    end = new Date(now.getTime() + 300)

    errors = 0

    testFunc = ->
      try
        TurkServer.Timers.startNewRound(now, end)
      catch e
        # We should get at least one error here.
        console.log(e)
        errors++

    # Make sure that running a bunch of these simultaneously doesn't bug out
    Meteor.defer(testFunc) for _ in [1..10]

    Meteor.setTimeout ->
      # TODO: do something smarter with RoundTimers.find().fetch()
      test.isTrue(errors > 0)
      test.isTrue(errors < 10)

      next()
    , 500

Tinytest.addAsync "timers - reschedule on server restart", withCleanup (test, next) ->
  Partitioner.bindGroup testGroup, ->
    now = new Date

    TurkServer.Timers.onRoundEnd ->
      test.ok()
      # Cancel group binding
      Partitioner._currentGroup.withValue(null, next)

    TurkServer.Timers.startNewRound(now, new Date(now.getTime() + 100))

    # Prevent the normal timeout from being called
    Meteor.clearTimeout(TestUtils.lastScheduledRound);

    # Pretend the server restarted
    TestUtils.scheduleOutstandingRounds();

