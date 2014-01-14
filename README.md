turkserver-meteor
=================

Implementation of the [TurkServer](https://github.com/HarvardEconCS/TurkServer) functionality as a plugin for the mind-blowing [Meteor](http://www.meteor.com/) web app framework, allowing Meteor apps to be easily modified for MTurk experiments. Using this, will make your online experiments much easier to create and manage.

## Usage

turkserver-meteor is a [smart package](https://atmosphere.meteor.com/) for your Meteor app, that is designed to sit on top of the main interface for your experiment and manage it.

Start by developing your application as a standalone Meteor app for a single instance of your experiment. Add TurkServer to your application as a smart package. You'll be able to do this with [Meteorite](https://github.com/oortcloud/meteorite) once development is closer to a public release.

Once added, you can navigate to `/turkserver` to log into the administration interface.

### Setting up collections

It's easy to use TurkServer because it takes full advantage of Meteor's powerful publish-subscribe data framework.

`TurkServer.registerCollection` tells makes a collection scope to each instance of an experiment.

### Initializing a treatment

`TurkServer.initialize` registers a callback handler when an experiment is created. All collection operations inside this handler will be scoped to the experiment.

**It's important to ensure that you do not do any yielding operations inside this handler.**

### The Lobby

TurkServer provides a lobby for grouping users into synchronous experiments.

### Tutorial and Quiz

TurkServer allows you to administer tutorials and quizzes for your participants to ensure understanding.

### Exit Surveys

Use an exit survey to collect final data and debrief participants.

## Settings

Put a structure like the following in `Meteor.settings` of your app.

```js
"turkserver": {
    "adminPassword": "something",
    "hits": {
        "acceptUnknownHits": true
    },
    "mturk": {
        "accessKeyId": "Your_AWS_Access_Key",
        "secretAccessKey": "Your_AWS_Secret_Key"
    }
}
```

Details are explained below.

- `adminPassword`: The password you will use to log in to the web interface.

### `hits`

- `acceptUnknownHits`: `true`/`false` whether to accept unrecognized HITs (those not created or forgotten) by the server for tasks. Needed for testing and generally safe, but leaves open the possibility of malicious behavior.

### `mturk`

- `accessKey`: Your AWS Access Key ID.
- `secretKey`: Your AWS Secret Access Key.
