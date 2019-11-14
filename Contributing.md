## Code

This repo is written in ES6 with a `.prettierrc` to auto-format code.

Initial parts of this codebase were written in Coffeescript. However, ES6
implements many useful functions from Coffeescript while allowing more people to
read the code and contribute. We [decaffeinated] the repo and in the future may
convert fully to TypeScript.

[decaffeinated]: https://github.com/TurkServer/turkserver-meteor/pull/99

TODO: set up format or lint hooks with something like AirBnb's [Javascript style
guide](https://github.com/airbnb/javascript).

## Testing

Clone this entire repository:

```
git clone https://github.com/TurkServer/turkserver-meteor.git turkserver
```

Then run the tests:

```
cd turkserver
meteor --release METEOR.VERSION test-packages ./
```

Where you should replace `METEOR.VERSION` with the `api.versionsFrom` specified in `package.json`.
If you checked out the repository into an existing Meteor app, you can run `meteor test-packages turkserver` from your app instead.

Browse to `http://localhost:3000` to run the tests.

You don't have to run the tests yourself; this project is set up for continuous integration on [Travis CI](https://travis-ci.org/TurkServer/turkserver-meteor), which runs these tests on each commit.
