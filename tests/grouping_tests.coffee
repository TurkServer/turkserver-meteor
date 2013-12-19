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
          console.log "collections inconsistently exist"
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

        # Enable direct insert - comes before the other insert hook modifies groupId
        collection.before.insert (userId, doc) ->
          if doc._direct
            delete doc._direct
            @_super.call(@context, doc)
            return false
          return

        # Attach the turkserver hooks to the collection
        TurkServer.registerCollection(collection)

        # Enable direct find which removes the added _groupId after the find hook
        collection.before.find (userId, selector, options) ->
          if options._direct
            delete selector._groupId # This is what I added before

      cursors.push( collection.find() )
      return collection

    # defined collections
    basicInsertCollection = defineCollection.call(this, "basicInsert", true) #insecure
    twoGroupCollection = defineCollection.call(this, "twoGroup", true)

    Meteor._debug "grouping publication activated"

    if needToConfigure
      twoGroupCollection.insert
        _direct: true
        _groupId: myGroup
        a: 1

      twoGroupCollection.insert
        _direct: true
        _groupId: otherGroup
        a: 1

      Meteor._debug "collections configured"
    else
      Meteor._debug "skipping configuration"

    return cursors

  Meteor.methods
    serverUpdate: (name, selector, mutator) ->
      return groupingCollections[name].update(selector, mutator)
    serverRemove: (name, selector) ->
      return groupingCollections[name].remove(selector)
    getCollection: (name, selector) ->
      return groupingCollections[name].find(selector || {}, {_direct: true}).fetch()
    getMyCollection: (name, selector) ->
      return groupingCollections[name].find(selector || {}).fetch()
    printCollection: (name) ->
      console.log groupingCollections[name].find({}, {_direct: true}).fetch()
    printMyCollection: (name) ->
      console.log groupingCollections[name].find().fetch()


if Meteor.isClient
  runTests = ->
    ###
      These tests need to all async so they are in the right order
    ###

    # Ensure that the group id has been recorded before subscribing
    Tinytest.addAsync "grouping - received group id", (test, next) ->
      Deps.autorun (c) ->
        record = Meteor.user()
        if record?.turkserver?.group
          c.stop()
          next()

    # Set up a bunch of test collections... on the client! They match the ones
    # created by setUpAllowTestsCollections.
    nonce = Random.id()

    # Tell the server to make, configure, and publish a set of collections unique
    # to our test run. Since the method does not unblock, this will complete
    # running on the server before anything else happens.
    Tinytest.addAsync "grouping - test subscriptions ready", (test, next) ->
      handle = Meteor.subscribe("groupingTests", nonce)

      Deps.autorun (c) ->
        if handle.ready()
          c.stop()
          next()

    Tinytest.addAsync "grouping - create collections", (test, next) ->
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

      # resticted collection with same allowed modifications, both with and
      # without the `insecure` package
      window.basicInsertCollection = defineCollection("basicInsert")
      window.twoGroupCollection = defineCollection("twoGroup")

      next()

    Tinytest.addAsync "grouping - local empty find", (test, next) ->
      test.equal basicInsertCollection.find().count(), 0
      next()

    testAsyncMulti "grouping - basic insert", [
      (test, expect) ->
        id = basicInsertCollection.insert { a: 1 }, expect (err, res) ->
          test.isFalse err, JSON.stringify(err)
          test.equal res, id
    , (test, expect) ->
        test.equal basicInsertCollection.find({a: 1}).count(), 1
        test.equal basicInsertCollection.findOne(a: 1)._groupId, myGroup
    ]

    testAsyncMulti "grouping - find from two groups", [ (test, expect) ->
      test.equal twoGroupCollection.find().count(), 1
      Meteor.call "getCollection", "twoGroup" + nonce, expect (err, res) ->
        test.isFalse err
        test.equal res.length, 2
    ]

    testAsyncMulti "grouping - insert into two groups", [
      (test, expect) ->
        twoGroupCollection.insert {a: 2}, expect (err) ->
          test.isFalse err, JSON.stringify(err)
          test.equal twoGroupCollection.find().count(), 2
    , (test, expect) ->
        Meteor.call "getMyCollection", "twoGroup" + nonce, expect (err, res) ->
          test.isFalse err, JSON.stringify(err)
          test.equal res.length, 2
    , (test, expect) -> # Ensure that the other half is still on the server
        Meteor.call "getCollection", "twoGroup" + nonce, expect (err, res) ->
          test.isFalse err, JSON.stringify(err)
          test.equal res.length, 3
    ]

    testAsyncMulti "grouping - server update identical keys across groups", [
      (test, expect) ->
        Meteor.call "serverUpdate", "twoGroup" + nonce,
          {a: 1},
          $set: { b: 1 }, expect (err, res) ->
            test.isFalse err
    , (test, expect) -> # Make sure that the other group's record didn't get updated
        Meteor.call "getCollection", "twoGroup" + nonce, expect (err, res) ->
          test.isFalse err
          _.each res, (doc) ->
            if doc.a is 1 and doc._groupId is myGroup
              test.equal doc.b, 1
            else
              test.isFalse doc.b
    ]

    testAsyncMulti "grouping - server remove identical keys across groups", [
      (test, expect) ->
        Meteor.call "serverRemove", "twoGroup" + nonce,
          {a: 1}, expect (err, res) ->
            test.isFalse err
    , (test, expect) -> # Make sure that the other group's record didn't get updated
        Meteor.call "getCollection", "twoGroup" + nonce, {a: 1}, expect (err, res) ->
          test.isFalse err
          test.equal res.length, 1
          test.equal res[0].a, 1
    ]

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

