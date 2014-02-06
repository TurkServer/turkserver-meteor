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

# Initialize some helpful qualifications
Meteor.startup ->
  return if Qualifications.find().count() > 0

  # US Worker
  Qualifications.insert
    name: "US Worker"
    QualificationTypeId: "00000000000000000071"
    Comparator: "EqualTo"
    LocaleValue: "US"

  # 100 HITs
  Qualifications.insert
    name: "> 100 HITs"
    QualificationTypeId: "00000000000000000040"
    Comparator: "GreaterThan"
    IntegerValue: "100"

  # 95% Approval
  Qualifications.insert
    name: "95% Approval"
    QualificationTypeId: "000000000000000000L0"
    Comparator: "GreaterThanOrEqualTo"
    IntegerValue: "95"

  # Adult Worker
  Qualifications.insert
    name: "Adult Worker"
    QualificationTypeId: "00000000000000000060"
    Comparator: "EqualTo"
    IntegerValue: "1"
