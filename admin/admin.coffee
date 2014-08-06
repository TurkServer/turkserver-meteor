# Server admin code
isAdmin = (userId) -> userId? and Meteor.users.findOne(userId)?.admin

# Only admin gets server facts
Facts.setUserIdFilter(isAdmin)

###
  TODO eliminate unnecessary fields sent over below
###

# Publish all admin data for /turkserver
Meteor.publish "tsAdmin", ->
  return [] unless isAdmin(@userId)

  return [
    Batches.find(),
    Treatments.find(),
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

Meteor.publish "tsAdminUsers", (groupId) ->
  return [] unless isAdmin(@userId)

  # When in a group, override whatever user publication the group sends with our fields
  # TODO Don't publish all users for /turkserver
  return Meteor.users.find({}, userFindOptions)

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

  exp = Experiments.findOne(groupId)
  return [] unless exp

  # This won't update if users changes, but it shouldn't after an experiment is completed
  # TODO Just return everything here; we don't know what the app subscription was using
  return Meteor.users.find({ _id: $in: exp.users}, offlineFindOptions)

# Get a date that is `days` away from `date`, locked to day boundaries
# See https://kadira.io/academy/improve-cpu-and-network-usage/
getDateFloor = (date, days) ->
  timestamp = date.valueOf()
  closestDay = timestamp - (timestamp % (24 * 3600 * 1000))
  return new Date(closestDay + days * 24 * 3600 * 1000)

# Data for a single worker
Meteor.publish "tsAdminWorkerData", (workerId) ->
  return [] unless isAdmin(@userId)
  check(workerId, String)

  # TODO also return users here if they are not all published
  return [
    Workers.find(workerId),
    Assignments.find({workerId})
  ]

Meteor.publish "tsAdminWorkers", ->
  return [] unless isAdmin(@userId)
  return [
    Workers.find(),
    WorkerEmails.find()
  ]

Meteor.publish "tsAdminActiveAssignments", (batchId) ->
  return [] unless isAdmin(@userId)
  check(batchId, String)

  # TODO this isn't fully indexed
  return Assignments.find({
    batchId,
    submitTime: null,
    status: "assigned"
  })

Meteor.publish "tsAdminCompletedAssignments", (batchId, days, limit) ->
  return [] unless isAdmin(@userId)
  check(batchId, String)
  check(days, Number)
  check(limit, Number)

  threshold = getDateFloor(new Date, -days)

  # effectively { status: "completed" } but there is an index on submitTime
  return Assignments.find({
    batchId,
    submitTime: { $gte: threshold }
  }, {
    sort: { submitTime: -1 }
    limit: limit
  })

# Publish a single instance to the admin.
Meteor.publish "tsAdminInstance", (instance) ->
  return [] unless isAdmin(@userId)
  check(instance, String)
  return Experiments.find(instance)

# Two separate publications for running and completed experiments, because
# it's hard to do both endTime: null and endTime > some date while sorting by
# endTime desc, because null sorts below any value.
Meteor.publish "tsAdminBatchRunningExperiments", (batchId) ->
  return [] unless isAdmin(@userId)
  check(batchId, String)

  return Experiments.find({batchId, endTime: null})

Meteor.publish "tsAdminBatchCompletedExperiments", (batchId, days, limit) ->
  return [] unless isAdmin(@userId)
  check(batchId, String)
  check(days, Number)
  check(limit, Number)

  threshold = getDateFloor(new Date, -days)

  return Experiments.find({
    batchId,
    endTime: { $gte: threshold }
  }, {
    sort: { endTime: -1 }
    limit: limit
  })

Meteor.publish "tsGroupLogs", (groupId, limit) ->
  return [] unless isAdmin(@userId)

  return [
    Experiments.find(groupId),
    Logs.find({_groupId: groupId}, {
      sort: {_timestamp: -1},
      limit: limit
    })
  ]

# Get a HIT Type and make sure it is ready for use
getAndCheckHitType = (hitTypeId) ->
  hitType = HITTypes.findOne(HITTypeId: hitTypeId)
  throw new Meteor.Error(403, "HITType not registered") unless hitType.HITTypeId
  batch = Batches.findOne(hitType.batchId)
  throw new Meteor.Error(403, "Batch not active; activate it first") unless batch.active
  return hitType

Meteor.methods
  "ts-admin-account-balance": ->
    TurkServer.checkAdmin()
    try
      return TurkServer.mturk "GetAccountBalance", {}
    catch e
      throw new Meteor.Error(403, e.toString())

  # This is the only method that uses the _id field of HITType instead of HITTypeId.
  "ts-admin-register-hittype": (hitType_id) ->
    TurkServer.checkAdmin()
    # Build up the params to register the HIT Type
    params = HITTypes.findOne(hitType_id)
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

      # Integer value is fine as array or not, but
      # Get the locale into its weird structure
      if Array.isArray(qual.LocaleValue)
        qual.LocaleValue = ({ Country: locale } for locale in qual.LocaleValue)
      else if qual.LocaleValue
        qual.LocaleValue = { Country: qual.LocaleValue }

      quals.push qual

    params.QualificationRequirement = quals

    hitTypeId = null
    try
      hitTypeId = TurkServer.mturk "RegisterHITType", params
    catch e
      throw new Meteor.Error(500, e.toString())

    HITTypes.update hitType_id,
      $set: {HITTypeId: hitTypeId}
    return

  "ts-admin-create-hit": (hitTypeId, params) ->
    TurkServer.checkAdmin()

    hitType = getAndCheckHitType(hitTypeId)

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
      HITTypeId: hitType.HITTypeId

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

    # TODO: don't allow change if the old HIT Type has a different batchId from the new one
    try
      TurkServer.mturk "ChangeHITTypeOfHIT", params
      @unblock() # If successful, refresh the HIT
      Meteor.call "ts-admin-refresh-hit", params.HITId
    catch e
      throw new Meteor.Error(500, e.toString())

    return

  "ts-admin-extend-hit": (params) ->
    TurkServer.checkAdmin()
    check(params.HITId, String)

    hit = HITs.findOne(HITId: params.HITId)

    getAndCheckHitType(hit.HITTypeId)

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

  "ts-admin-create-message": (subject, message, copyFromId) ->
    TurkServer.checkAdmin()
    check(subject, String)
    check(message, String)

    if copyFromId?
      recipients = WorkerEmails.findOne(copyFromId)?.recipients

    recipients ?= []

    return WorkerEmails.insert({ subject, message, recipients })

  "ts-admin-send-message": (emailId) ->
    TurkServer.checkAdmin()
    check(emailId, String)

    email = WorkerEmails.findOne(emailId)
    recipients = email.recipients

    check(email.subject, String)
    check(email.message, String)
    check(recipients, Array)

    throw new Error(403, "No recipients on e-mail") if recipients.length is 0

    count = 0

    while recipients.length > 0
      # Notify workers 50 at a time
      chunk = recipients.splice(0, 50)

      params =
        Subject: email.subject
        MessageText: email.message
        WorkerId: chunk

      try
        TurkServer.mturk "NotifyWorkers", params
      catch e
        throw new Meteor.Error(500, e.toString())

      count += chunk.length
      Meteor._debug(count + " workers notified")

      # Record which workers got the e-mail in case something breaks
      Workers.update({_id: $in: chunk}, {
        $push: {emailsReceived: emailId}
      }, {multi: true})

    # Record date that this was sent
    WorkerEmails.update emailId,
      $set: sentTime: new Date

    return count

  # TODO implement this
  "ts-admin-resend-message": (emailId) ->
    TurkServer.checkAdmin()
    check(emailId, String)

    throw new Meteor.Error(500, "Not implemented")

  "ts-admin-delete-message": (emailId) ->
    TurkServer.checkAdmin()
    check(emailId, String)

    email = WorkerEmails.findOne(emailId)
    throw new Meteor.Error(403, "Email has already been sent") if email.sentTime

    WorkerEmails.remove(emailId)
    return

  "ts-admin-cleanup-user-state": ->
    TurkServer.checkAdmin()
    # Find all users that are state: experiment but don't have an active assignment
    # This shouldn't have to be used in most cases
    Meteor.users.find({"turkserver.state": "experiment"}).map (user) ->
      return if TurkServer.Assignment.getCurrentUserAssignment(user._id)?
      Meteor.users.update user._id,
        $unset: "turkserver.state": null

    return

  "ts-admin-cancel-assignments": (batchId) ->
    TurkServer.checkAdmin()
    check(batchId, String)

    count = 0
    Assignments.find({batchId, status: "assigned"}).map (asst) ->
      return if Meteor.users.find({workerId: asst.workerId}).status?.online
      TurkServer.Assignment.getAssignment(asst._id).setReturned()
      count++
    return count

  "ts-admin-refresh-assignment": (asstId) ->
    TurkServer.checkAdmin()
    check(asstId, String)

    TurkServer.Assignment.getAssignment(asstId).refreshStatus()
    return

  "ts-admin-stop-experiment": (groupId) ->
    TurkServer.checkAdmin()
    check(groupId, String)

    TurkServer.Instance.getInstance(groupId).teardown()
    return

  "ts-admin-stop-all-experiments": (batchId) ->
    TurkServer.checkAdmin()
    check(batchId, String)

    count = 0
    Experiments.find({batchId, endTime: {$exists: false} }).map (instance) ->
      TurkServer.Instance.getInstance(instance._id).teardown()
      count++

    return count

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
