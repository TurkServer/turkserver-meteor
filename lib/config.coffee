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
      set: 1
    }
  },
  mturk: {
    sandbox: true
    accessKeyId: undefined
    secretAccessKey: undefined
  },
}

TurkServer.config = merge(defaultSettings, Meteor.settings?.turkserver || {})
