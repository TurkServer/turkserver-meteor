# Process config from settings

merge = Npm.require('deepmerge')

# These are just here for reference
defaultPublicSettings = {
  watchRoute: "/"
}

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
  }
}

TurkServer.config = merge(defaultSettings, Meteor.settings?.turkserver || {})

