# Process config from settings

merge = Npm.require('deepmerge')

defaultSettings = {
  adminPassword: undefined,
  hits: {
    acceptUnknownHits: true
  },
  experiment : {
    limit: {
      simultaneous: 1
      batch: 1
    }
  },
  mturk: {
    sandbox: true
    accessKeyId: undefined
    secretAccessKey: undefined
  },
  watchRoute: "/"
}

TurkServer.config = merge(defaultSettings, Meteor.settings?.turkserver || {})

# Publish static config variables
Meteor.publish null, ->
  sub = this
  sub.added "ts.config", "watchRoute", { value: TurkServer.config.watchRoute }
  sub.ready()
