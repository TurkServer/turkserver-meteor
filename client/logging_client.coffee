TurkServer.log = (doc, callback) ->
  Meteor.call "ts-log", doc, callback

###
  Submits the exit survey data to the server and submits the HIT if successful
###
TurkServer.submitExitSurvey = (doc) ->
  Meteor.call "ts-submit-exitdata", doc, (err, res) ->
    bootbox.alert(err) if err
    TurkServer.submitHIT() if res
