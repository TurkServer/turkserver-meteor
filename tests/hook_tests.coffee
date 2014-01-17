testUsername = "hooks_foo"
testGroupId = "hooks_bar"

if Meteor.isClient
  # Tests for client-side hooks - don't require a login
  Tinytest.add "grouping - hooks - admin removed on client finds", (test) ->
    ctx =
      args: []

    TurkServer.groupingHooks.userFindHook.call(ctx, undefined, ctx.args[0], ctx.args[1])
    # Should have nothing changed
    test.length ctx.args, 0

    TurkServer.groupingHooks.userFindHook.call(ctx, userId, ctx.args[0], ctx.args[1])
    # Should replace undefined with { _groupId: ... }
    test.equal ctx.args[0].admin.$exists, false

if Meteor.isServer
  userId = null
  try
    userId = Accounts.createUser
      username: testUsername
  catch
    userId = Meteor.users.findOne(username: testUsername)._id

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

    TurkServer.groupingHooks.userFindHook.call(ctx, userId, ctx.args[0], ctx.args[1])
    # Should replace undefined with { _groupId: ... }
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

  Tinytest.add "grouping - hooks - user find with selector", (test) ->
    ctx =
      args: [ { foo: "bar" } ]

    TurkServer.groupingHooks.userFindHook.call(ctx, undefined, ctx.args[0], ctx.args[1])
    # Should have nothing changed
    test.equal ctx.args[0].foo, "bar"
    test.isFalse ctx.args[0]["turkserver.group"]

    TurkServer.groupingHooks.userFindHook.call(ctx, userId, ctx.args[0], ctx.args[1])
    # Should modify the selector
    test.equal ctx.args[0].foo, "bar"
    test.equal ctx.args[0]["turkserver.group"], testGroupId
    test.equal ctx.args[0].admin.$exists, false
