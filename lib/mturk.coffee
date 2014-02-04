mturkAPI = undefined

if not TurkServer.config.mturk.accessKeyId or not TurkServer.config.mturk.secretAccessKey
  Meteor._debug "Missing Amazon API keys for connecting to MTurk. Please configure."
else
  settings =
    sandbox: TurkServer.config.mturk.sandbox
    creds:
      accessKey: TurkServer.config.mturk.accessKeyId
      secretKey: TurkServer.config.mturk.secretAccessKey

  mturkAPI = mturk(settings)

TurkServer.mturk = (op, params) ->
  unless mturkAPI
    console.log "Ignoring operation " + op + " because MTurk is not configured."
    return
  throw new Error("undefined mturk operation") unless mturkAPI[op]
  syncFunc = Meteor._wrapAsync mturkAPI[op].bind mturkAPI
  return syncFunc(params)

try
  bal = TurkServer.mturk "GetAccountBalance", {}
  console.log "Balance in Account: " + bal
catch e
  console.log e

