
if not TurkServer.config.mturk.accessKeyId or not TurkServer.config.mturk.secretAccessKey
  Meteor._debug "Missing Amazon API keys for connecting to MTurk. Please configure."
else
  settings =
    sandbox: TurkServer.config.mturk.sandbox
    creds:
      accessKey: TurkServer.config.mturk.accessKeyId
      secretKey: TurkServer.config.mturk.secretAccessKey

  TurkServer.mturk = mturk(settings)

  TurkServer.mturk.GetAccountBalance {}, Meteor.bindEnvironment (err, res) ->
    if err
      console.log(err)
    else
      console.log(res)


