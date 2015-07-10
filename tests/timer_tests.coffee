testGroup = "timerTest"

# use a before here because tests are async
withCleanup = TestUtils.getCleanupWrapper
  before: ->
    Partitioner.bindGroup testGroup, ->
      RoundTimers.remove {}
    TestUtils.clearRoundHandlers()

Tinytest.addAsync "timers - expiration callback", withCleanup (test, next) ->
  Partitioner.bindGroup testGroup, ->
    now = Date.now()

    TurkServer.Timers.onRoundEnd ->
      test.ok()
      # Cancel group binding
      Partitioner._currentGroup.withValue(null, next)

    TurkServer.Timers.startNewRound now, now + 100

Tinytest.addAsync "timers - early expiration", withCleanup (test, next) ->
  Partitioner.bindGroup testGroup, ->
    now = Date.now()

    count = 0

    TurkServer.Timers.onRoundEnd -> count++

    TurkServer.Timers.startNewRound now, now + 100

    TurkServer.Timers.endCurrentRound()

    # round end callback should only have been called once
    Meteor.setTimeout ->
      test.equal(count, 1)
      # Cancel group binding
      Partitioner._currentGroup.withValue(null, next)
    , 150

Tinytest.addAsync "timers - reschedule on server restart", withCleanup (test, next) ->
  Partitioner.bindGroup testGroup, ->
    now = Date.now()

    TurkServer.Timers.onRoundEnd ->
      test.ok()
      # Cancel group binding
      Partitioner._currentGroup.withValue(null, next)

    TurkServer.Timers.startNewRound(now, now + 100)

    # Prevent the normal timeout from being called
    Meteor.clearTimeout(TestUtils.lastScheduledRound);

    # Pretend the server restarted
    TestUtils.scheduleOutstandingRounds();

