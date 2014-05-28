UI.registerHelper "_tsDebug", ->
  console.log @, arguments

# Submit as soon as this template appears on the page.
Template.mturkSubmit.rendered = -> @find("form").submit()

Template.tsTimePicker.zone = -> moment().format("Z")

Template.tsTimeOptions.momentList = ->
  # Default time selections: 9AM EST to 11PM EST
  m = moment.utc(hours: 9 + 5).local()
  return (m.clone().add('hours', x) for x in [0..14])

# Store all values in GMT-5
Template.tsTimeOptions.valueFormatted = -> @zone(300).format('HH ZZ')

# Display values in user's timezone
Template.tsTimeOptions.displayFormatted = -> @local().format('hA [UTC]Z')

###
  Submits the exit survey data to the server and submits the HIT if successful
###
TurkServer.submitExitSurvey = (results, panel) ->
  Meteor.call "ts-submit-exitdata", results, panel, (err, res) ->
    bootbox.alert(err) if err
    TurkServer.submitHIT() if res
    # TODO: log the user out here? Maybe doesn't matter because resume login will be disabled

TurkServer.submitHIT = -> UI.insert UI.render(Template.mturkSubmit), document.body

