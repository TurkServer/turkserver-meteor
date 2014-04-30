###
  Reactive time functions
###
class TurkServer.Timers
  # Milliseconds elapsed since experiment start
  @elapsedTime: ->
    return unless (exp = Experiments.findOne())?
    return unless exp.startTime?
    return Math.max(0, TimeSync.serverTime() - exp.startTime)

  @remainingTime: ->
    return unless (exp = Experiments.findOne())?
    return unless exp.endTime?
    return Math.max(0, exp.endTime - TimeSync.serverTime())

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
  diff = moment.utc(millis)
  time = diff.format("H:mm:ss")
  days = +diff.format("DDD") - 1
  return (if days then days + "d " else "") + time

UI.registerHelper "tsElapsedTime", ->
  formatSeconds TurkServer.Timers.elapsedTime()

UI.registerHelper "tsRemainingTime", ->
  formatSeconds TurkServer.Timers.remainingTime()

UI.registerHelper "tsRoundElapsedTime", ->
  formatSeconds TurkServer.Timers.roundElapsedTime()

UI.registerHelper "tsRoundRemainingTime", ->
  formatSeconds TurkServer.Timers.roundRemainingTime()

UI.registerHelper "tsBreakRemainingTime", ->
  formatSeconds TurkServer.Timers.breakRemainingTime()
