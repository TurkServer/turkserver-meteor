testUsername = "hooks_foo"
testGroupId = "hooks_bar"

if Meteor.isServer
  userId = null
  try
    userId = Accounts.createUser
      username: testUsername
  catch
    userId = Meteor.users.findOne(username: testUsername)._id

  TurkServer.addUserToGroup userId, testGroupId

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
