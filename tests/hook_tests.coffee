testUsername = "hooks_foo"
testGroupId = "hooks_bar"

if Meteor.isClient
  # XXX All async here to ensure ordering

  Tinytest.addAsync "grouping - hooks - ensure logged in", (test, next) ->
    InsecureLogin.ready next

  Tinytest.addAsync "grouping - hooks - add client group", (test, next) ->
    Meteor.call "joinGroup", testGroupId, (err, res) ->
      test.isFalse err
      next()

  Tinytest.addAsync "grouping - hooks - vanilla client find", (test, next) ->
    ctx =
      args: []

    TurkServer.groupingHooks.userFindHook.call(ctx, undefined, ctx.args[0], ctx.args[1])
    # Should have nothing changed
    test.length ctx.args, 0

    TurkServer.groupingHooks.userFindHook.call(ctx, userId, ctx.args[0], ctx.args[1])
    # Also nothing changed
    test.length ctx.args, 0

    next()

  Tinytest.addAsync "grouping - hooks - set admin", (test, next) ->
    Meteor.call "setAdmin", true, (err, res) ->
      test.isFalse err
      test.isTrue Meteor.user().admin
      next()

  Tinytest.addAsync "grouping - hooks - admin hidden in client find", (test, next) ->
    ctx =
      args: []

    TurkServer.groupingHooks.userFindHook.call(ctx, undefined, ctx.args[0], ctx.args[1])
    # Should have nothing changed
    test.length ctx.args, 0

    TurkServer.groupingHooks.userFindHook.call(ctx, Meteor.userId(), ctx.args[0], ctx.args[1])
    # Admin removed from find
    test.equal ctx.args[0].admin.$exists, false
    next()

  Tinytest.addAsync "grouping - hooks - admin hidden in selector find", (test, next) ->
    ctx =
      args: [ { foo: "bar" }]

    TurkServer.groupingHooks.userFindHook.call(ctx, undefined, ctx.args[0], ctx.args[1])
    # Should have nothing changed
    test.length ctx.args, 1
    test.equal ctx.args[0].foo, "bar"

    TurkServer.groupingHooks.userFindHook.call(ctx, Meteor.userId(), ctx.args[0], ctx.args[1])
    # Admin removed from find
    test.equal ctx.args[0].foo, "bar"
    test.equal ctx.args[0].admin.$exists, false
    next()

  # Need to remove admin to avoid fubars in other tests
  Tinytest.addAsync "grouping - hooks - unset admin", (test, next) ->
    Meteor.call "setAdmin", false, (err, res) ->
      test.isFalse err
      test.isFalse Meteor.user().admin
      next()

if Meteor.isServer
  userId = null
  ungroupedUserId = null
  try
    userId = Accounts.createUser
        username: testUsername
  catch
    userId = Meteor.users.findOne(username: testUsername)._id

  try
    ungroupedUserId = Accounts.createUser
      username: "blahblah"
  catch
    ungroupedUserId = Meteor.users.findOne(username: "blahblah")._id

  TurkServer.Groups.clearUserGroup userId
  TurkServer.Groups.setUserGroup userId, testGroupId

  Tinytest.add "grouping - hooks - find with no args", (test) ->
    ctx =
      args: []

    TurkServer.groupingHooks.findHook.call(ctx, userId, ctx.args[0], ctx.args[1])
    # Should replace undefined with { _groupId: ... }
    test.equal ctx.args[0]._groupId, testGroupId

  Tinytest.add "grouping - hooks - find with string id", (test) ->
    ctx =
      args: [ "yabbadabbadoo" ]

    TurkServer.groupingHooks.findHook.call(ctx, userId, ctx.args[0], ctx.args[1])
    # Should not touch a string
    test.equal ctx.args[0], "yabbadabbadoo"

  Tinytest.add "grouping - hooks - find with single _id", (test) ->
    ctx =
      args: [ {_id: "yabbadabbadoo"} ]

    TurkServer.groupingHooks.findHook.call(ctx, userId, ctx.args[0], ctx.args[1])
    # Should not touch a single object
    test.equal ctx.args[0]._id, "yabbadabbadoo"
    test.isFalse ctx.args[0]._groupId

  Tinytest.add "grouping - hooks - find with selector", (test) ->
    ctx =
      args: [ { foo: "bar" } ]

    TurkServer.groupingHooks.findHook.call(ctx, userId, ctx.args[0], ctx.args[1])
    # Should not touch a string
    test.equal ctx.args[0].foo, "bar"
    test.equal ctx.args[0]._groupId, testGroupId

  Tinytest.add "grouping - hooks - insert doc", (test) ->
    ctx =
      args: [ { foo: "bar" } ]

    TurkServer.groupingHooks.insertHook.call(ctx, userId, ctx.args[0])
    # Should add the group id
    test.equal ctx.args[0].foo, "bar"
    test.equal ctx.args[0]._groupId, testGroupId

  Tinytest.add "grouping - hooks - user find with no args", (test) ->
    ctx =
      args: []

    TurkServer.groupingHooks.userFindHook.call(ctx, undefined, ctx.args[0], ctx.args[1])
    # Should have nothing changed
    test.length ctx.args, 0

    # Ungrouped user should throw an error
    test.throws ->
      TurkServer.groupingHooks.userFindHook.call(ctx, ungroupedUserId, ctx.args[0], ctx.args[1])
    (e) -> e.error is 403 and e.reason is ErrMsg.groupErr

    TurkServer.groupingHooks.userFindHook.call(ctx, userId, ctx.args[0], ctx.args[1])
    # Should replace undefined with { _groupId: ... }
    test.equal ctx.args[0]["turkserver.group"], testGroupId
    test.equal ctx.args[0].admin.$exists, false

  Tinytest.add "grouping - hooks - user find with environment group but no userId", (test) ->
    ctx =
      args: []

    TurkServer._currentGroup.withValue testGroupId, ->
      TurkServer.groupingHooks.userFindHook.call(ctx, undefined, ctx.args[0], ctx.args[1])
      # Should have set the extra arguments
      test.equal ctx.args[0]["turkserver.group"], testGroupId
      test.equal ctx.args[0].admin.$exists, false

  Tinytest.add "grouping - hooks - user find with string id", (test) ->
    ctx =
      args: [ "yabbadabbadoo" ]

    TurkServer.groupingHooks.userFindHook.call(ctx, undefined, ctx.args[0], ctx.args[1])
    # Should have nothing changed
    test.equal ctx.args[0], "yabbadabbadoo"

    TurkServer.groupingHooks.userFindHook.call(ctx, userId, ctx.args[0], ctx.args[1])
    # Should not touch a string
    test.equal ctx.args[0], "yabbadabbadoo"

  Tinytest.add "grouping - hooks - user find with single _id", (test) ->
    ctx =
      args: [ {_id: "yabbadabbadoo"} ]

    TurkServer.groupingHooks.userFindHook.call(ctx, undefined, ctx.args[0], ctx.args[1])
    # Should have nothing changed
    test.equal ctx.args[0]._id, "yabbadabbadoo"
    test.isFalse ctx.args[0]["turkserver.group"]

    TurkServer.groupingHooks.userFindHook.call(ctx, userId, ctx.args[0], ctx.args[1])
    # Should not touch a single object
    test.equal ctx.args[0]._id, "yabbadabbadoo"
    test.isFalse ctx.args[0]["turkserver.group"]

  Tinytest.add "grouping - hooks - user find with username", (test) ->
    ctx =
      args: [ {username: "yabbadabbadoo"} ]

    TurkServer.groupingHooks.userFindHook.call(ctx, undefined, ctx.args[0], ctx.args[1])
    # Should have nothing changed
    test.equal ctx.args[0].username, "yabbadabbadoo"
    test.isFalse ctx.args[0]["turkserver.group"]

    TurkServer.groupingHooks.userFindHook.call(ctx, userId, ctx.args[0], ctx.args[1])
    # Should not touch a single object
    test.equal ctx.args[0].username, "yabbadabbadoo"
    test.isFalse ctx.args[0]["turkserver.group"]

  Tinytest.add "grouping - hooks - user find with selector", (test) ->
    ctx =
      args: [ { foo: "bar" } ]

    TurkServer.groupingHooks.userFindHook.call(ctx, undefined, ctx.args[0], ctx.args[1])
    # Should have nothing changed
    test.equal ctx.args[0].foo, "bar"
    test.isFalse ctx.args[0]["turkserver.group"]

    # Ungrouped user should throw an error
    test.throws ->
      TurkServer.groupingHooks.userFindHook.call(ctx, ungroupedUserId, ctx.args[0], ctx.args[1])
    (e) -> e.error is 403 and e.reason is ErrMsg.groupErr

    TurkServer.groupingHooks.userFindHook.call(ctx, userId, ctx.args[0], ctx.args[1])
    # Should modify the selector
    test.equal ctx.args[0].foo, "bar"
    test.equal ctx.args[0]["turkserver.group"], testGroupId
    test.equal ctx.args[0].admin.$exists, false
