myGroup = "group1"
otherGroup = "group2"
username = "fooser"

if Meteor.isServer

  # Set up allow/deny rules for test collections
  allowCollections = {}

  # We create the collections in the publisher (instead of using a method or
  # something) because if we made them with a method, we'd need to follow the
  # method with some subscribes, and it's possible that the method call would
  # be delayed by a wait method and the subscribe messages would be sent before
  # it and fail due to the collection not yet existing. So we are very hacky
  # and use a publish.
  Meteor.publish "groupingTests", (nonce) ->
    check(nonce, String)
    cursors = []
    needToConfigure = `undefined`

    # set group of user
    Meteor.users.update @userId,
      $set: {
        "turkserver.group": myGroup
      }

    # helper for defining a collection. we are careful to create just one
    # Meteor.Collection even if the sub body is rerun, by caching them.
    defineCollection = (name, insecure, transform) ->
      fullName = name + nonce
      collection = undefined
      if _.has(allowCollections, fullName)
        collection = allowCollections[fullName]
        throw new Error("collections inconsistently exist")  if needToConfigure is true
        needToConfigure = false
      else
        collection = new Meteor.Collection(fullName,
          transform: transform
        )
        allowCollections[fullName] = collection
        throw new Error("collections inconsistently don't exist")  if needToConfigure is false
        needToConfigure = true
        collection._insecure = insecure
        m = {}
        m["clear-collection-" + fullName] = ->
          collection.remove {}

        Meteor.methods(m)
      cursors.push collection.find()
      collection

    # defined collections
    foo = defineCollection("foo", true) #insecure

    return cursors

if Meteor.isClient

  runTests = ->
    # Set up a bunch of test collections... on the client! They match the ones
    # created by setUpAllowTestsCollections.
    nonce = Random.id()

    # Tell the server to make, configure, and publish a set of collections unique
    # to our test run. Since the method does not unblock, this will complete
    # running on the server before anything else happens.
    Meteor.subscribe("groupingTests", nonce)

    # helper for defining a collection, subscribing to it, and defining
    # a method to clear it
    defineCollection = (name, transform) ->
      fullName = name + nonce
      collection = new Meteor.Collection(fullName,
        transform: transform
      )
      collection.callClearMethod = (callback) ->
        Meteor.call "clear-collection-" + fullName, callback

      collection.unnoncedName = name
      collection

    # resticted collection with same allowed modifications, both with and
    # without the `insecure` package
    foo = defineCollection("foo")

    testAsyncMulti "grouping - insert", [(test, expect) ->
        id = foo.insert { a: 1 }, expect (err, res) ->
          test.equal res, id
          console.log foo.find({})
    ]

  Meteor.insecureUserLogin(username, runTests)

