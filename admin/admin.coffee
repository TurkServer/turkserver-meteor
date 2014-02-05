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

  cursors = [ Meteor.users.find {}, userFindOptions ]
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

# Publish admin role for users that have it
Meteor.publish null, ->
  return unless @userId
  return Meteor.users.find @userId,
    fields: {admin: 1}

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

  "ts-admin-join-group": (groupId) ->
    checkAdmin()
    TurkServer.Groups.setUserGroup Meteor.userId(), groupId

  "ts-admin-leave-group": ->
    checkAdmin()
    TurkServer.Groups.clearUserGroup Meteor.userId()

  "ts-admin-stop-experiment": (groupId) ->
    checkAdmin()
    TurkServer.Experiment.complete(groupId)

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
