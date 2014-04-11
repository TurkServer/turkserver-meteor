# Start a new round; callback is triggered at the end of the round
# only if the round is not ended prematurely
TurkServer.startNewRound = (startTime, endTime, callback) ->
  interval = endTime - Date.now()
  throw new Error("endTime is in the past") if interval < 0
  
  if (currentRound = RoundTimers.findOne(active: true))?
    # current round already exists
    # cancel any scheduled callback
    Meteor.clearTimeout(currentRound.timeoutId) if currentRound.timeoutId

    RoundTimers.update currentRound._id,
      $set:
        active: false
      $unset:
        timeoutId: null

    index = currentRound.index + 1
  else
    index = 1

  timeoutId = Meteor.setTimeout(callback, interval)

  RoundTimers.insert
    index: index
    startTime: startTime
    endTime: endTime
    active: true
    timeoutId: timeoutId

# Stop the current round early
TurkServer.endCurrentRound = ->
  unless (currentRound = RoundTimers.findOne(active: true))?
    throw new Error("No current round to end")

  now = Date.now()
  unless currentRound.endTime > now
    throw new Error("Current round is already ended")

  # Cancel any callback, if it is scheduled
  Meteor.clearTimeout(currentRound.timeoutId)

  RoundTimers.update currentRound._id,
    $set:
      endTime: now
    $unset:
      timeoutId: null


