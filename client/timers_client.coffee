###
  Reactive time functions
###

# Milliseconds elapsed since experiment start
TurkServer.elapsedTime = ->
  return unless (exp = Experiments.findOne())?
  return unless exp.startTime?
  return Math.max(0, TimeSync.serverTime() - exp.startTime)

TurkServer.remainingTime = ->
  return unless (exp = Experiments.findOne())?
  return unless exp.endTime?
  return Math.max(0, exp.endTime - TimeSync.serverTime())

# Milliseconds elapsed since round start
TurkServer.roundElapsedTime = ->
  return unless (round = TurkServer.currentRound())?
  return unless round.startTime?
  return Math.max(0, TimeSync.serverTime() - round.startTime)

# Milliseconds until end of round
TurkServer.roundRemainingTime = ->
  return unless (round = TurkServer.currentRound())?
  return unless round.endTime?
  return Math.max(0, round.endTime - TimeSync.serverTime())

# Milliseconds until start of next round, if any
TurkServer.breakRemainingTime = ->
  return unless (round = TurkServer.currentRound())?
  return unless (nextRound = RoundTimers.findOne(index: round.index + 1))?
  return unless nextRound.startTime?
  return Math.max(0, nextRound.startTime - TimeSync.serverTime())

# UI Time helpers

formatSeconds = (millis) ->
  diff = moment.utc(millis)
  time = diff.format("H:mm:ss")
  days = +diff.format("DDD") - 1
  return (if days then days + "d " else "") + time

Handlebars.registerHelper "tsElapsedTime", ->
  formatSeconds TurkServer.elapsedTime()

Handlebars.registerHelper "tsRemainingTime", ->
  formatSeconds TurkServer.remainingTime()

Handlebars.registerHelper "tsRoundElapsedTime", ->
  formatSeconds TurkServer.roundElapsedTime()

Handlebars.registerHelper "tsRoundRemainingTime", ->
  formatSeconds TurkServer.roundRemainingTime()

Handlebars.registerHelper "tsBreakRemainingTime", ->
  formatSeconds TurkServer.breakRemainingTime()
