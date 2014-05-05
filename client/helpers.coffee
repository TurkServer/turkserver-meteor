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

TurkServer.submitHIT = -> UI.insert UI.render(Template.mturkSubmit), document.body

