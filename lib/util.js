// TODO: This file was created by bulk-decaffeinate.
// Sanity-check the conversion and remove this comment.
/*
 * decaffeinate suggestions:
 * DS102: Remove unnecessary code created because of implicit returns
 * DS207: Consider shorter variations of null checks
 * Full docs: https://github.com/decaffeinate/decaffeinate/blob/master/docs/suggestions.md
 */
/*
  Server/client util files
*/

if (TurkServer.Util == null) { TurkServer.Util = {}; }

TurkServer.Util.formatMillis = function(millis) {
  if (millis == null) { return; } // Can be 0 in which case we should render it
  const negative = (millis < 0);
  const diff = moment.utc(Math.abs(millis));
  const time = diff.format("H:mm:ss");
  const days = +diff.format("DDD") - 1;
  return (negative ? "-" : "") + (days ? days + "d " : "") + time;
};

TurkServer._mergeTreatments = function(arr) {
  const fields =
    {treatments: []};
  arr.forEach(function(treatment) {
    fields.treatments.push(treatment.name);
    return _.extend(fields, _.omit(treatment, "_id", "name"));
  });
  return fields;
};
