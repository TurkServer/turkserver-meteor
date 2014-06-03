###
  Reactive time functions
###
class TurkServer.Timers
  _currentAssignmentInstance = ->
    return if TurkServer.isAdmin()
    return unless (group = TurkServer.group())?
    _.find(Assignments.findOne()?.instances, (inst) -> inst.id is group)

  _joinedTime = (instance, serverTime) -> Math.max(0, serverTime - instance.joinTime)

  _idleTime = (instance, serverTime) ->
    idleMillis = (instance.idleTime || 0)
    # If we're idle, add the local idle time (as it's not updated from the server)
    # TODO add a test for this part - difficult because user-status is a different package
    if UserStatus.isIdle()
      idleMillis += serverTime - UserStatus.lastActivity()
    return idleMillis

  _disconnectedTime = (instance) -> instance.disconnectedTime || 0

  # Milliseconds elapsed since experiment start
  @elapsedTime: ->
    return unless (exp = Experiments.findOne())?
    return unless exp.startTime?
    return Math.max(0, TimeSync.serverTime() - exp.startTime)

  # Milliseconds elapsed since this user joined the experiment instance
  # This is slightly different than the above
  @joinedTime: ->
    return unless (instance = _currentAssignmentInstance())?
    return _joinedTime(instance, TimeSync.serverTime())

  @remainingTime: ->
    return unless (exp = Experiments.findOne())?
    return unless exp.endTime?
    return Math.max(0, exp.endTime - TimeSync.serverTime())

  ###
    Emboxed values below because they aren't using per-second reactivity
  ###

  # Milliseconds this user has been idle in the experiment
  @idleTime: UI.emboxValue ->
    return unless (instance = _currentAssignmentInstance())?
    return _idleTime(instance, TimeSync.serverTime())

  # Milliseconds this user has been disconnected in the experiment
  @disconnectedTime: UI.emboxValue (instance) ->
    return unless (instance = _currentAssignmentInstance())?
    return _disconnectedTime(instance)

  @activeTime: =>
    return unless (instance = _currentAssignmentInstance())?
    # Compute this using helper functions to avoid thrashing
    serverTime = TimeSync.serverTime()
    _joinedTime(instance, serverTime) - _idleTime(instance, serverTime) - _disconnectedTime(instance)

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
  return unless millis? # Can be 0 in which case we should render it
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

TestUtils.formatSeconds = formatSeconds

