# Server admin code

# Only admin gets server facts
Facts.setUserIdFilter (userId) -> Meteor.users.findOne(userId)?.admin

Meteor.publish "tsAdmin", ->
  return unless @userId and Meteor.users.findOne(@userId).admin

  # Publish all admin data
  return [
    Batches.find(),
    Treatments.find(),
    # Grouping.find(),
    Assignments.find(),
    Workers.find(),
    Qualifications.find(),
    HITTypes.find(),
    HITs.find(),
    LobbyStatus.find()
  ]

userFindOptions =
  fields:
    status: 1
    turkserver: 1
    username: 1
    workerId: 1

# Admin users - needs to update if group updates
# Return all experiments unless in a group
Meteor.publish "tsAdminState", (groupId) ->
  return unless @userId and Meteor.users.findOne(@userId).admin

  cursors = [ Meteor.users.find({}, userFindOptions) ]
  cursors.push Experiments.find() unless groupId # taken care of in tsCurrentExperiment

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

checkAdmin = ->
  throw new Meteor.Error(403, "Not logged in as admin") unless Meteor.user()?.admin

Meteor.methods
  "ts-admin-activate-batch": (batchId) ->
    checkAdmin()

    activeBatch = Batches.findOne(batchId)
    if activeBatch.grouping is "groupCount"
      # Make sure we have enough experiments in this batch
      numExps = activeBatch?.experimentIds?.length || 0
      while numExps++ < activeBatch.groupVal
        # TODO pick treatments properly
        treatmentId = _.sample activeBatch.treatmentIds
        treatment = Treatments.findOne(treatmentId).name
        expId = TurkServer.Experiment.create(treatment)
        TurkServer.Experiment.setup(expId)
        Batches.update batchId,
          $addToSet: experimentIds: expId

    Batches.update batchId, $set:
      active: true
    return

  "ts-admin-account-balance": ->
    checkAdmin()
    try
      return TurkServer.mturk "GetAccountBalance", {}
    catch e
      throw new Meteor.Error(403, e.toString())

  "ts-admin-register-hittype": (hitTypeId) ->
    checkAdmin()
    # Build up the params to register the HIT Type
    params = HITTypes.findOne(hitTypeId)
    delete params._id

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
    checkAdmin()
    hitType = HITTypes.findOne(hitTypeId)
    throw new Meteor.Error(403, "HITType not registered") unless hitType.HITTypeId

    params.HITTypeId = hitType.HITTypeId
    params.Question =
      """<ExternalQuestion xmlns="http://mechanicalturk.amazonaws.com/AWSMechanicalTurkDataSchemas/2006-07-14/ExternalQuestion.xsd">
          <ExternalURL>#{TurkServer.config.mturk.externalUrl}</ExternalURL>
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
    checkAdmin()
    throw new Meteor.Error(400, "HIT ID not specified") unless HITId
    try
      hitData = TurkServer.mturk "GetHIT", HITId: HITId
      HITs.update {HITId: HITId}, $set: hitData
    catch e
      throw new Meteor.Error(500, e.toString())

    return

  "ts-admin-expire-hit": (HITId) ->
    checkAdmin()
    throw new Meteor.Error(400, "HIT ID not specified") unless HITId
    try
      hitData = TurkServer.mturk "ForceExpireHIT", HITId: HITId

      @unblock() # If successful, refresh the HIT
      Meteor.call "ts-admin-refresh-hit", HITId
    catch e
      throw new Meteor.Error(500, e.toString())

    return

  "ts-admin-change-hittype": (params) ->
    checkAdmin()
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
    checkAdmin()
    throw new Meteor.Error(400, "HIT ID not specified") unless params.HITId
    try
      TurkServer.mturk "ExtendHIT", params

      @unblock() # If successful, refresh the HIT
      Meteor.call "ts-admin-refresh-hit", params.HITId
    catch e
      throw new Meteor.Error(500, e.toString())

    return

  "ts-admin-join-group": (groupId) ->
    checkAdmin()
    Partitioner.setUserGroup Meteor.userId(), groupId
    return

  "ts-admin-leave-group": ->
    checkAdmin()
    Partitioner.clearUserGroup Meteor.userId()
    return

  "ts-admin-stop-experiment": (groupId) ->
    checkAdmin()
    TurkServer.Experiment.complete(groupId)
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
