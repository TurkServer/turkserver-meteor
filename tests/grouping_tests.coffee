myGroup = "group1"
otherGroup = "group2"
username = "fooser"

if Meteor.isServer
  # Add a group to anyone who logs in
  Meteor.users.find("profile.online": true).observeChanges
    added: (id) ->
      Meteor.users.update id,
        $set: {
          "turkserver.group": myGroup
        }

  # Set up allow/deny rules for test collections
  groupingCollections = {}

  # We create the collections in the publisher (instead of using a method or
  # something) because if we made them with a method, we'd need to follow the
  # method with some subscribes, and it's possible that the method call would
  # be delayed by a wait method and the subscribe messages would be sent before
  # it and fail due to the collection not yet existing. So we are very hacky
  # and use a publish.
  Meteor.publish "groupingTests", (nonce) ->
    return unless @userId

    check(nonce, String)
    cursors = []
    needToConfigure = `undefined`

    # helper for defining a collection. we are careful to create just one
    # Meteor.Collection even if the sub body is rerun, by caching them.
    defineCollection = (name, insecure, transform) ->
      fullName = name + nonce

      if _.has(groupingCollections, fullName)
        collection = groupingCollections[fullName]
        if needToConfigure is true
          consdole.log "collections inconsistently exist"
          throw new Error("collections inconsistently exist")
        needToConfigure = false
      else
        collection = new Meteor.Collection(fullName,
          transform: transform
        )
        groupingCollections[fullName] = collection
        if needToConfigure is false
          console.log "collections inconsistently don't exist"
          throw new Error("collections inconsistently don't exist")
        needToConfigure = true
        collection._insecure = insecure

        m = {}
        m["clear-collection-" + fullName] = -> collection.remove({})
        Meteor.methods(m)

        # Attach the turkserver hooks to the collec tion
        TurkServer.registerCollection(collection)

      # TODO we need to figure out some way to get this.userId to the hook
      cursors.push( collection.find({}, {}, @userId) )
      return collection

    # defined collections
    basicInsertCollection = defineCollection.call(this, "basicInsert", true) #insecure
    twoGroupCollection = defineCollection.call(this, "twoGroup", true)

    Meteor._debug "grouping publication activated"

    if needToConfigure
      twoGroupCollection.noHookInsert
        groupId: myGroup
        a: myGroup
      twoGroupCollection.noHookInsert
        groupId: otherGroup
        a: otherGroup

      Meteor._debug "collections configured"
    else
      Meteor._debug "skipping configuration"

    return cursors

if Meteor.isClient
  runTests = ->
    # Ensure that the group id has been recorded before subscribing
    Tinytest.addAsync "grouping - received group id", (test, next) ->
      Deps.autorun (c) ->
        if Meteor.user()?.turkserver?.group
          c.stop()
          next()

    # Set up a bunch of test collections... on the client! They match the ones
    # created by setUpAllowTestsCollections.
    nonce = Random.id()

    console.log "subscribing to group: " + nonce
    # Tell the server to make, configure, and publish a set of collections unique
    # to our test run. Since the method does not unblock, this will complete
    # running on the server before anything else happens.
    Meteor.subscribe("groupingTests", nonce)
    console.log "done subscription"

    # helper for defining a collection, subscribing to it, and defining
    # a method to clear it
    defineCollection = (name, transform) ->
      fullName = name + nonce

      collection = new Meteor.Collection fullName,
        transform: transform

      collection.callClearMethod = (callback) ->
        Meteor.call "clear-collection-" + fullName, callback

      collection.unnoncedName = name

      TurkServer.registerCollection(collection)
      return collection

    console.log "defining collections"

    # resticted collection with same allowed modifications, both with and
    # without the `insecure` package
    window.basicInsertCollection = defineCollection("basicInsert")
    window.twoGroupCollection = defineCollection("twoGroup")

    console.log "starting grouping tests"

    Tinytest.add "grouping - local empty find", (test) ->
      test.equal basicInsertCollection.find().count(), 0

    testAsyncMulti "grouping - basic insert", [
      (test, expect) ->
        id = basicInsertCollection.insert { a: 1 }, expect (err, res) ->
          test.isFalse err, JSON.stringify(err)
          test.equal res, id
    , (test, expect) ->
        test.equal basicInsertCollection.find({a: 1}).count(), 1
        test.equal basicInsertCollection.findOne(a: 1)._groupId, myGroup
    ]

    Tinytest.add "grouping - find from two groups", (test) ->
      test.equal twoGroupCollection.find().count(), 1
      # TODO Make sure other stuff isn't actually sent over from the server

  # Ensure we are logged in before running these tests
  # TODO can we provide a better way to ensure this login?

  if Meteor.userId()
    Meteor._debug "running grouping tests"
    runTests()
  else
    Meteor._debug "logging in to run grouping tests"
    Tinytest.addAsync "grouping - dummy login", (test, next) ->
      Meteor.insecureUserLogin(username, next)
    runTests()

