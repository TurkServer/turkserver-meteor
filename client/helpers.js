/*
 * decaffeinate suggestions:
 * DS102: Remove unnecessary code created because of implicit returns
 * DS207: Consider shorter variations of null checks
 * Full docs: https://github.com/decaffeinate/decaffeinate/blob/master/docs/suggestions.md
 */
UI.registerHelper("_tsDebug", function() {
  return console.log(this, arguments);
});

if (TurkServer.Util == null) { TurkServer.Util = {}; }

TurkServer.Util._defaultTimeSlots = function() {
  // Default time selections: 9AM EST to 11PM EST
  const m = moment.utc({hours: 9 + 5}).local();
  return ([0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14].map((x) => m.clone().add(x, 'hours')));
};

// Submit as soon as this template appears on the page.
Template.mturkSubmit.rendered = function() { return this.find("form").submit(); };

Template.tsTimePicker.helpers({
  zone() { return moment().format("Z"); }});

Template.tsTimeOptions.helpers({
  momentList: TurkServer.Util._defaultTimeSlots});

Template.tsTimeOptions.helpers({
  // Store all values in GMT-5
  valueFormatted() { return this.zone(300).format('HH ZZ'); },
  // Display values in user's timezone
  displayFormatted() { return this.local().format('hA [UTC]Z'); }
});

/*
  Submits the exit survey data to the server and submits the HIT if successful
*/
TurkServer.submitExitSurvey = (results, panel) => Meteor.call("ts-submit-exitdata", results, panel, function(err, res) {
  if (err) { bootbox.alert(err); }

  if (res) {
    return TurkServer.submitHIT();
  }
});
      // TODO: log the user out here? Maybe doesn't matter because resume login will be disabled

TurkServer.submitHIT = () => Blaze.render(Template.mturkSubmit, document.body);

