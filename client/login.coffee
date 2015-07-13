unescapeURL = (s) ->
  decodeURIComponent s.replace(/\+/g, "%20")

getURLParams = ->
  params = {}
  m = window.location.href.match(/[\\?&]([^=]+)=([^&#]*)/g)
  if m
    i = 0
    while i < m.length
      a = m[i].match(/.([^=]+)=(.*)/)
      params[unescapeURL(a[1])] = unescapeURL(a[2])
      i++
  return params

params = getURLParams()

hitIsViewing = params.assignmentId and params.assignmentId is "ASSIGNMENT_ID_NOT_AVAILABLE"

# UI helpers for login
UI.registerHelper "hitParams", params
UI.registerHelper "hitIsViewing", hitIsViewing

# Subscribe to the currently viewed batch if in the preview page
# TODO: allow for reading meta properties later as well
if hitIsViewing and params.batchId?
  Meteor.subscribe "tsLoginBatches", params.batchId

loginCallback = (err) ->
  return unless err
  console.log err
  if err.reason is ErrMsg.alreadyCompleted
    # submit the HIT
    TurkServer.submitHIT()
  else
    bootbox.dialog
      closeButton: false
      message: "<p>Unable to login:</p>" + err.message

    # TODO: make this a bit more robust
    # Log us out even if the resume token logged us in; copied from
    # https://github.com/meteor/meteor/blob/devel/packages/accounts-base/accounts_client.js#L195
    Accounts.connection.setUserId(null)
    Accounts.connection.onReconnect = null

mturkLogin = (args) ->
  Accounts.callLoginMethod
    methodArguments: [ args ],
    userCallback: loginCallback

loginDialog = null

Template.tsTestingLogin.events =
  "submit form": (e, tmpl) ->
    e.preventDefault()
    batchId = tmpl.find("select[name=batch]").value
    return unless batchId
    console.log "Trying login with testing credentials"
    # Save parameters (including generated stuff) and login
    loginParams = _.extend @, {
      batchId: batchId
      test: true
    }

    Session.set("_loginParams", loginParams)
    mturkLogin(loginParams)

    loginDialog?.modal('hide')
    loginDialog = null

# Subscribe to the list of batches only when this dialog is open
Template.tsTestingLogin.rendered = ->
  @subHandle = Meteor.subscribe("tsLoginBatches")

Template.tsTestingLogin.destroyed = ->
  @subHandle.stop()

Template.tsTestingLogin.helpers
  batches: -> Batches.find()

testLogin = ->
  # FIXME hack: never run this if we are live
  return if hitIsViewing
  return if window.location.protocol is "https:" or window isnt window.parent
  # Don't try logging in if we are logged in or already have parameters
  return if Meteor.userId() or Session.get("_loginParams")
  # Don't show this if we are trying to get at the admin interface
  return if Router.current()?.path?.indexOf("/turkserver") is 0

  str = Random.id()
  data =
    hitId: str + "_HIT"
    assignmentId: str + "_Asst"
    workerId: str + "_Worker"

  loginDialog = TurkServer._displayModal(Template.tsTestingLogin, data, {
    title: 'Select batch'
    message: " "
  })

  return

# Remember our previous hit parameters unless they have been replaced
# TODO make sure this doesn't interfere with actual HITs
if params.hitId and params.assignmentId and params.workerId
  Session.set("_loginParams", {
    hitId: params.hitId
    assignmentId: params.assignmentId
    workerId: params.workerId
    batchId: params.batchId
    # TODO: hack to allow testing logins
    test: params.test? || params.workerId.indexOf("_Worker") >= 0
  })
  Meteor._debug "Captured login params"

# Recover either page params or stored session params as above
loginParams = Session.get("_loginParams")

if loginParams

  Meteor._debug "Logging in with captured or stored parameters"
  mturkLogin(loginParams)
else
  # Give enough time to log in some other way before showing login dialog
  TurkServer._delayedStartup testLogin, 1000

# TODO Testing disconnect and reconnect, remove later
TurkServer.testingLogin = ->
  if Meteor.user()
    console.log "Already logged in."
    return
  unless Session.get("_loginParams")
    console.log "No parameters saved."
    return
  mturkLogin(Session.get("_loginParams"))

