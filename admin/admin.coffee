# Server admin code

Meteor.publish "tsAdmin", ->
  return unless @userId and Meteor.users.findOne(@userId).admin

  # Publish all admin data
  return [
    Batches.find(),
    Treatments.find(),
    Experiments.find(),
    # Grouping.find(),
    Assignments.find(),
    Workers.find(),
    LobbyStatus.find()
  ]

# Admin users - needs to update if group updates
Meteor.publish "tsAdminUsers", (groupId) ->
  return unless @userId and Meteor.users.findOne(@userId).admin

  return Meteor.users.find {},
    # {"status.online": true},
    fields:
      status: 1
      turkserver: 1
      workerId: 1

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
        expId = TurkServer.Experiment.create(treatmentId)
        TurkServer.Experiment.setup(expId, Treatments.findOne(treatmentId).name)
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
