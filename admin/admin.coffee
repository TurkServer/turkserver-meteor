# Server admin code

Meteor.publish "tsAdmin", ->
  return unless @userId and Meteor.users.findOne(@userId).admin

  # Publish all admin data
  return [
    Meteor.users.find(
      {"profile.online": true},
      fields:
        profile: 1
        turkserver: 1
        workerId: 1
    ),
    Batches.find(),
    Treatments.find(),
    Experiments.find(),
    Grouping.find(),
    Assignments.find(),
    Workers.find(),
    Lobby.find()
  ]

# Publish admin role for users that have it
Meteor.publish null, -> Meteor.users.find({_id: @userId, admin: true})

# Create and set up admin user (and password) if not existent
Meteor.startup ->
  adminPw = Meteor.settings?.turkserver?.adminPassword
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
