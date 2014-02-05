TurkServer.log = (doc, callback) ->
  Meteor.call "ts-log", doc, callback

###
  Submits the exit survey data to the server and submits the HIT if successful
###
TurkServer.submitExitSurvey = (results, panel) ->
  Meteor.call "ts-submit-exitdata", results, panel, (err, res) ->
    bootbox.alert(err) if err
    TurkServer.submitHIT() if res
