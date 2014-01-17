
if Meteor.isClient
  # Prevent router from complaining about missing path
  Router.map -> @route("/")

if Meteor.isServer
  Meteor.methods
    setAdmin: (value) ->
      throw new Meteor.Error(403, "not logged in") unless Meteor.userId()
      if value
        Meteor.users.update Meteor.userId(),
          $set: admin: true
      else
        Meteor.users.update Meteor.userId(),
          $unset: admin: null
    joinGroup: (myGroup) ->
      userId = Meteor.userId()
      throw new Error(403, "Not logged in") unless userId
      TurkServer.Groups.clearUserGroup userId
      TurkServer.Groups.setUserGroup(userId, myGroup)
