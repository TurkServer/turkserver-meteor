# Process config from settings

os = Npm.require('os')
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
    externalUrl: "https://" + os.hostname()
    frameHeight: 900
  }
}

TurkServer.config = merge(defaultSettings, Meteor.settings?.turkserver || {})

