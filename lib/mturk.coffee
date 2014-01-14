
if not TurkServer.config.mturk.accessKeyId or not TurkServer.config.mturk.secretAccessKey
  Meteor._debug "Missing Amazon API keys for connecting to MTurk. Please configure."
else
  settings =
    url: if Turkserver.config.mturk.sandbox is false
    then "https://mechanicalturk.amazonaws.com"
    else "https://mechanicalturk.sandbox.amazonaws.com"
    accessKeyId: TurkServer.config.accessKeyId
    secretAccessKey: TurkServer.config.secretAccessKey

  TurkServer.mturk = Npm.require('mturk')(settings)

