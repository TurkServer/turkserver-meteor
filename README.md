turkserver-meteor
=================

Implementation of the [TurkServer](https://github.com/HarvardEconCS/TurkServer) functionality as a plugin for the mind-blowing [Meteor](http://www.meteor.com/) web app framework, allowing Meteor apps to be easily modified for MTurk experiments. Using this, will make your online experiments much easier to create and manage.

## Usage

TBD when development is closer to completion.

turkserver-meteor is a [smart package](https://atmosphere.meteor.com/) for your Meteor app, that is designed to sit on top of the main interface for your experiment and manage it.

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
