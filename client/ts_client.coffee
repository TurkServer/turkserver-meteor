# Client-only pseudo collection that receives experiment metadata
@TSConfig = new Meteor.Collection("ts.config")

# TODO perhaps make a better version of this reactivity
Deps.autorun ->
  userId = Meteor.userId()
  return unless userId
  turkserver = Meteor.users.findOne(
    _id: userId
    "turkserver.state": { $exists: true }
  , fields:
    "turkserver.state" : 1
  )?.turkserver
  return unless turkserver

  Session.set("turkserver.state", turkserver.state)

# Reactive variables for state
TurkServer.inQuiz = ->
  Session.equals("turkserver.state", "quiz")

TurkServer.inLobby = ->
  Session.equals("turkserver.state", "lobby")

TurkServer.inExperiment = ->
  Session.equals("turkserver.state", "experiment")

TurkServer.group = ->
  TSConfig.findOne("groupId")?.value

TurkServer.treatment = ->
  TSConfig.findOne("treatment")?.value

Template.tsTimePicker.zone = -> moment().format("Z")

Template.tsTimeOptions.momentList = ->
  # Default time selections: 9AM EST to 11PM EST
  m = moment.utc(hours: 9 + 5).local()
  return (m.clone().add('hours', x) for x in [0..14])

# Store all values in GMT-5
Template.tsTimeOptions.valueFormatted = -> @zone(300).format('HH ZZ')

# Display values in user's timezone
Template.tsTimeOptions.displayFormatted = -> @local().format('hA [UTC]Z')
