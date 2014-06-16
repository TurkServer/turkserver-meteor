# Server admin code
isAdmin = (userId) -> userId? and Meteor.users.findOne(userId)?.admin

# Only admin gets server facts
Facts.setUserIdFilter(isAdmin)

Meteor.publish "tsAdmin", ->
  return [] unless isAdmin(@userId)

  # Publish all admin data
  return [
    Batches.find(),
    Workers.find(),
    Qualifications.find(),
    HITTypes.find(),
    HITs.find(),
  ]

userFindOptions =
  fields:
    status: 1
    turkserver: 1
    username: 1
    workerId: 1

# Batch-specific filters for assignments, experiment instances, and lobby
Meteor.publish "tsAdminState", (batchId, groupId) ->
  return [] unless isAdmin(@userId)

  # When in a group, only users should be returned.
  # needs to update if group updates
  cursors = [ Meteor.users.find({}, userFindOptions) ]

  unless groupId # specific experiment/treatment sent in tsCurrentExperiment
    # Return nothing if no batch is selected
    batchSelector = if batchId then {batchId} else undefined
    cursors.push Assignments.find(batchSelector)
    cursors.push LobbyStatus.find(batchSelector)
    cursors.push Experiments.find(batchSelector)
    cursors.push Treatments.find()

  return cursors

# Don't return status here as the user is not connected to this experiment
offlineFindOptions =
  fields:
    turkserver: 1
    username: 1
    workerId: 1

# Helper publish function to get users for experiments that have ended.
# Necessary to watch completed experiments.
Meteor.publish "tsGroupUsers", (groupId) ->
  return [] unless isAdmin(@userId)
  sub = this
  exp = Experiments.findOne(groupId)
  return unless exp

  # This won't update if users changes, but it shouldn't after an experiment is completed
  # TODO Just return everything here; we don't know what the app subscription was using
  subHandle = Meteor.users.find({ _id: $in: exp.users}, offlineFindOptions).observeChanges
    added: (id, fields) ->
      sub.added "users", id, fields
    changed: (id, fields) ->
      sub.changed "users", id, fields
    removed: (id) ->
      sub.removed "users", id

  sub.ready()
  sub.onStop -> subHandle.stop()

Meteor.publish "tsGroupLogs", (groupId, limit) ->
  return [] unless isAdmin(@userId)

  return Logs.find({_groupId: groupId}, {
      sort: {_timestamp: -1},
      limit: limit
    })

Meteor.methods
  "ts-admin-account-balance": ->
    TurkServer.checkAdmin()
    try
      return TurkServer.mturk "GetAccountBalance", {}
    catch e
      throw new Meteor.Error(403, e.toString())

  "ts-admin-register-hittype": (hitTypeId) ->
    TurkServer.checkAdmin()
    # Build up the params to register the HIT Type
    params = HITTypes.findOne(hitTypeId)
    delete params._id
    delete params.batchId

    params.Reward =
      Amount: params.Reward
      CurrencyCode: "USD"

    quals = []
    for i, qualId of params.QualificationRequirement
      qual = Qualifications.findOne(qualId)
      delete qual._id
      delete qual.name
      # Get the locale into its weird structure
      qual.LocaleValue = { Country: qual.LocaleValue } if qual.LocaleValue
      quals.push qual

    params.QualificationRequirement = quals

    id = null
    try
      id = TurkServer.mturk "RegisterHITType", params
    catch e
      throw new Meteor.Error(500, e.toString())

    HITTypes.update hitTypeId,
      $set: {HITTypeId: id}
    return

  "ts-admin-create-hit": (hitTypeId, params) ->
    TurkServer.checkAdmin()
    hitType = HITTypes.findOne(hitTypeId)
    throw new Meteor.Error(403, "HITType not registered") unless hitType.HITTypeId

    params.HITTypeId = hitType.HITTypeId
    params.Question =
      """<ExternalQuestion xmlns="http://mechanicalturk.amazonaws.com/AWSMechanicalTurkDataSchemas/2006-07-14/ExternalQuestion.xsd">
          <ExternalURL>#{TurkServer.config.mturk.externalUrl}?batchId=#{hitType.batchId}</ExternalURL>
          <FrameHeight>#{TurkServer.config.mturk.frameHeight}</FrameHeight>
        </ExternalQuestion>
      """

    hit = null
    try
      hit = TurkServer.mturk "CreateHIT", params
    catch e
      throw new Meteor.error(500, e.toString())

    HITs.insert
      HITId: hit
      HitTypeId: hitType.HITTypeId

    return

  "ts-admin-refresh-hit": (HITId) ->
    TurkServer.checkAdmin()
    throw new Meteor.Error(400, "HIT ID not specified") unless HITId
    try
      hitData = TurkServer.mturk "GetHIT", HITId: HITId
      HITs.update {HITId: HITId}, $set: hitData
    catch e
      throw new Meteor.Error(500, e.toString())

    return

  "ts-admin-expire-hit": (HITId) ->
    TurkServer.checkAdmin()
    throw new Meteor.Error(400, "HIT ID not specified") unless HITId
    try
      hitData = TurkServer.mturk "ForceExpireHIT", HITId: HITId

      @unblock() # If successful, refresh the HIT
      Meteor.call "ts-admin-refresh-hit", HITId
    catch e
      throw new Meteor.Error(500, e.toString())

    return

  "ts-admin-change-hittype": (params) ->
    TurkServer.checkAdmin()
    check(params.HITId, String)
    check(params.HITTypeId, String)
    try
      TurkServer.mturk "ChangeHITTypeOfHIT", params
      @unblock() # If successful, refresh the HIT
      Meteor.call "ts-admin-refresh-hit", params.HITId
    catch e
      throw new Meteor.Error(500, e.toString())

    return

  "ts-admin-extend-hit": (params) ->
    TurkServer.checkAdmin()
    throw new Meteor.Error(400, "HIT ID not specified") unless params.HITId
    try
      TurkServer.mturk "ExtendHIT", params

      @unblock() # If successful, refresh the HIT
      Meteor.call "ts-admin-refresh-hit", params.HITId
    catch e
      throw new Meteor.Error(500, e.toString())

    return

  "ts-admin-join-group": (groupId) ->
    TurkServer.checkAdmin()
    Partitioner.setUserGroup Meteor.userId(), groupId
    return

  "ts-admin-leave-group": ->
    TurkServer.checkAdmin()
    Partitioner.clearUserGroup Meteor.userId()
    return

  "ts-admin-lobby-event": (batchId, event) ->
    TurkServer.checkAdmin()
    batch = TurkServer.Batch.getBatch(batchId)
    throw new Meteor.Error(500, "Batch #{batchId} does not exist") unless batch?
    emitter = batch.lobby.events
    emitter.emit.apply(emitter, Array::slice.call(arguments, 1)) # Event and any other arguments
    return

  "ts-admin-notify-workers": (subject, message, selector) ->
    TurkServer.checkAdmin()
    check(subject, String)
    check(message, String)

    workers = Workers.find(selector).map((w) -> w._id)
    return 0 unless workers.length > 0
    count = 0

    while workers.length > 0
      # Notify workers 50 at a time
      chunk = workers.splice(0, 50)

      params =
        Subject: subject
        MessageText: message
        WorkerId: chunk

      try
        TurkServer.mturk "NotifyWorkers", params
      catch e
        throw new Meteor.Error(500, e.toString())

      count += chunk.length

    return count

  "ts-admin-stop-experiment": (groupId) ->
    TurkServer.checkAdmin()
    TurkServer.Instance.getInstance(groupId).teardown()
    return

# Create and set up admin user (and password) if not existent
Meteor.startup ->
  adminPw = TurkServer.config?.adminPassword
  unless adminPw?
    Meteor._debug "No admin password found for Turkserver. Please configure it in your settings."
    return

  adminUser = Meteor.users.findOne(username: "admin")
  unless adminUser
    Accounts.createUser
      username: "admin"
      password: adminPw
    Meteor._debug "Created Turkserver admin user from Meteor.settings."

    Meteor.users.update {username: "admin"},
      $set: {admin: true}
  else
    # Make sure password matches that of settings file
    Accounts.setPassword(adminUser._id, adminPw)
