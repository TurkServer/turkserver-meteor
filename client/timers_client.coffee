###
  Reactive time functions
###
class TurkServer.Timers
  # Milliseconds elapsed since experiment start
  @elapsedTime: ->
    return unless (exp = Experiments.findOne())?
    return unless exp.startTime?
    return Math.max(0, TimeSync.serverTime() - exp.startTime)

  # Milliseconds elapsed since this user joined the experiment instance
  # This is slightly different than the above
  @joinedTime: ->
    return if TurkServer.isAdmin()
    return unless (instance = Assignments.findOne()?.instances?[0])?
    return Math.max(0, TimeSync.serverTime() - instance.joinTime)

  @remainingTime: ->
    return unless (exp = Experiments.findOne())?
    return unless exp.endTime?
    return Math.max(0, exp.endTime - TimeSync.serverTime())

  ###
    Emboxed values below because they aren't using per-second reactivity
  ###

  # Milliseconds this user has been idle in the experiment
  @idleTime: UI.emboxValue ->
    return if TurkServer.isAdmin()
    return unless (instance = Assignments.findOne()?.instances?[0])?
    return instance.idleTime || 0

  # Milliseconds this user has been disconnected in the experiment
  @disconnectedTime: UI.emboxValue ->
    return if TurkServer.isAdmin()
    return unless (instance = Assignments.findOne()?.instances?[0])?
    return instance.disconnectedTime || 0

  # Number of active milliseconds (= joined - idle - disconnected)
  @activeTime: =>
    @joinedTime() - @idleTime() - @disconnectedTime()

  # Milliseconds elapsed since round start
  @roundElapsedTime: ->
    return unless (round = TurkServer.currentRound())?
    return unless round.startTime?
    return Math.max(0, TimeSync.serverTime() - round.startTime)

  # Milliseconds until end of round
  @roundRemainingTime: ->
    return unless (round = TurkServer.currentRound())?
    return unless round.endTime?
    return Math.max(0, round.endTime - TimeSync.serverTime())

  # Milliseconds until start of next round, if any
  @breakRemainingTime: ->
    return unless (round = TurkServer.currentRound())?
    now = Date.now()
    if (round.startTime <= now and round.endTime >= now)
      # if we are not at a break, return 0
      return 0

    # if we are at a break, we already set next round to be active.
    return unless (nextRound = RoundTimers.findOne(index: round.index + 1))?
    return unless nextRound.startTime?
    return Math.max(0, nextRound.startTime - TimeSync.serverTime())

# UI Time helpers

formatSeconds = (millis) ->
  return unless millis
  diff = moment.utc(millis)
  time = diff.format("H:mm:ss")
  days = +diff.format("DDD") - 1
  return (if days then days + "d " else "") + time

# Register all the helpers in the form tsGlobalHelperTime
for own key of TurkServer.Timers
  # camelCase the helper name
  helperName = "ts" + key.charAt(0).toUpperCase() + key.slice(1)
  (-> # Bind the function to the current value inside the closure
    func = TurkServer.Timers[key]
    UI.registerHelper helperName, -> formatSeconds func()
  )()



