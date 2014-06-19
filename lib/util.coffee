###
  Server/client util files
###

TurkServer.Util ?= {}

TurkServer.Util.formatMillis = (millis) ->
  return unless millis? # Can be 0 in which case we should render it
  diff = moment.utc(millis)
  time = diff.format("H:mm:ss")
  days = +diff.format("DDD") - 1
  return (if days then days + "d " else "") + time

TurkServer._mergeTreatments = (arr) ->
  fields =
    treatments: []
  arr.forEach (treatment) ->
    fields.treatments.push treatment.name
    _.extend(fields, _.omit(treatment, "_id", "name"))
  return fields
