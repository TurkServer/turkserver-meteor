# Start a new round; callback is triggered at the end of the round
# only if the round is not ended prematurely
TurkServer.startNewRound = (startTime, endTime, callback) ->
  interval = endTime - Date.now()
  throw new Error("endTime is in the past") if interval < 0

  if (currentRound = RoundTimers.findOne({}, sort: {index: -1}) )?
    # current round already exists
    RoundTimers.update currentRound._id,
      $set:
        active: false

    index = currentRound.index + 1
  else
    index = 1

  Meteor.setTimeout(callback, interval) if callback?

  # We can't actually store the timeout in the database
  RoundTimers.insert
    index:      index
    startTime:  startTime
    endTime:    endTime
    active:     true

# Stop the current round early
TurkServer.endCurrentRound = ->
  unless (currentRound = RoundTimers.findOne(active: true))?
    throw new Error("No current round to end")

  now = Date.now()
  unless currentRound.endTime > now
    throw new Error("Current round is already ended")

  RoundTimers.update currentRound._id,
    $set:
      endTime: now
      active: false



