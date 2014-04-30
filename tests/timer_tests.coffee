testGroup = "timerTest"

# use a before here because tests are async
withCleanup = TestUtils.getCleanupWrapper
  before: ->
    Partitioner.bindGroup testGroup, ->
      RoundTimers.remove {}

Tinytest.addAsync "timers - expiration callback", withCleanup (test, next) ->
  Partitioner.bindGroup testGroup, ->
    now = Date.now()
    TurkServer.Timers.startNewRound now, now + 100, ->
      test.ok()
      next()

Tinytest.addAsync "timers - early expiration", withCleanup (test, next) ->
  Partitioner.bindGroup testGroup, ->
    now = Date.now()
    TurkServer.Timers.startNewRound now, now + 100, ->
      test.fail("This should not have been called")

    TurkServer.Timers.endCurrentRound()

    # wait to see if we have failed, otherwise we passed
    Meteor.setTimeout ->
      test.ok()
      next()
    , 150
