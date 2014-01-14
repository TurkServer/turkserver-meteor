TurkServer.log = (doc, callback) ->
  Meteor.call "ts-log", doc, callback
