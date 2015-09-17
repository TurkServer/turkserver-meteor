{{#template name="preamble"}}

# Getting Started

See the [Quick Start](https://github.com/HarvardEconCS/turkserver-meteor). Once the package is installed, you should be able to start your Meteor app and navigate to `/turkserver` to see the admin interface.

Be sure to also check out the excellent [tutorial](http://ldworkin.github.io/turkserver-tutorial/) written by [Lili Dworkin](https://github.com/ldworkin). 

# Administration Interface

TurkServer has a built-in administration interface at `/turkserver`. You can use this to manage batches, manage treatments, view the progress of experiments, and post HITs to recruit subjects. A brief overview of the different sections:

- **Overview**: provides a summary of traffic and load on the server.
- **MTurk**: manage HIT types and qualifications for Mechanical Turk.
- **HITs**: create, expire, and renew HITs, which will send participants to the server.
- **Workers**: look up information about particular workers who have participated in the past.
- **Panel**: summary of information about all workers known to the system.
- **Connections**: shows all currently connected users and their state.
- **Assignments**: shows currently active and completed assignments, and associated metadata.
- **Lobby**: shows all participants who are currently waiting for experiment instances (see below).
- **Experiments**: shows experiment instances, their participants, and timing information.
- **Manage**: controls batch and treatment data which are used to configure experiments.

# Notes and Troubleshooting

Because TurkServer runs alongside your app on both the server and client, strange behavior can occur when writing code without thoughtfulness. While we've tried our best to prevent easily-avoidable problems, some issues might still arise due to these reasons. These are some things to be aware of:

- **CSS conflicts**. TurkServer uses regular Bootstrap classes with no modification. If you use CSS classes that conflict with Bootstrap in your app, or selectors for unqualified tags, the admin backend will likely be messed up.
- **Meteor template name conflicts**. TurkServer templates all have the prefix `ts`.
- **Handlebars helper conflicts**. Internal TurkServer global helpers have the prefix `_ts`.

# API Reference

JSDoc-style comments in the code are automatically processed and included
below. This can change quite a bit as we approach a stable release. Some API
functions aren't yet documented, so [please
contribute](https://github.com/HarvardEconCS/turkserver-meteor)!

{{/template}}
