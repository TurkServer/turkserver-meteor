{{#template name="preamble"}}

# Overview

[Meteor](https://www.meteor.com) is a fantastic framework that makes building real-time web apps effortless, and iteration very fast.

**This makes it perfect for building web-based experiments.** But, you have to manage your subjects and the data that you collect.

TurkServer is a package that facilitates designing web-based user experiments using the power of Meteor. All you need to do is to learn Meteor. TurkServer gives you useful APIs when you need them, and will stay out of the way otherwise. It does this by sitting on top of the app that you design, intercepting the server-client communication, and then providing a management interface for your experiment.

TurkServer allows you to develop your application as a standalone Meteor app, i.e. for a single instance of your experiment. Then, add TurkServer to your application as a smart package, and you're pretty much ready to run.

# Installation

See the [Quick Start](https://github.com/HarvardEconCS/turkserver-meteor). Once the package is installed, you should be able to start your Meteor app and navigate to `/turkserver` to see the admin interface.

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

# Structuring Your App

TurkServer is designed around the Meteor framework. There are many reasons that Meteor is especially powerful for web development; see [this post](http://www.quora.com/Should-I-use-Meteor-Why) for a summary. But more importantly, there are [tons of learning resources](https://www.meteor.com/learn) for new users to get started. The design philosophy of TurkServer is to stick to standard Meteor as much as possible, while minimizing the need to use custom APIs. This means that most of the outstanding Meteor documentation on the Internet will be useful, and that most of the required knowledge is not specific to TurkServer.

Designing an experiment using TurkServer requires three main parts:

1. **Design the user interface and instructions**, using regular Meteor standards
2. **Specify the lobby mechanism** by which participants will be grouped and assigned to worlds - see [below](#lobby).
3. **Hook into the TurkServer API** to activate different worlds for experimental treatments.

Moreover, TurkServer is designed to take advantage of Meteor's fast prototyping abilities, so that you can do the first step in a bare Meteor app and add TurkServer later.

Meteor already makes it pretty easy to design a reactive and responsive user interface, but you may find some of the following packages useful.

- [Bootstrap](http://getbootstrap.com/), a CSS framework for front-end development. I maintain a Meteor package at [`mizzao:bootstrap-3`](https://github.com/mizzao/meteor-bootstrap-3/).
- [Tutorials](https://github.com/mizzao/meteor-tutorials), a Meteor-specific tutorials package that I wrote for providing interactive and concise instructions for web apps. Very useful for experiment instructions.

# Lobby and Experiment Instances

A main innovation of TurkServer is the use of experiment **worlds** or **instances** to divide up the data in the app. Each participant can be assigned to one world at a time, and participate in multiple worlds over the course of a HIT, so that each world can have one or more simultaneous participants. This makes experiments easy to design while taking full advantage of Meteor's powerful, standard publish-subscribe model - in many cases, multi-person interactions are just as simple as single-person interactions.

The **lobby** is a virtual area that holds participants when they are connected but not assigned to any world. Participants that are in the lobby can be shown to each other. An **assignment mechanism** controls the flow of participants that connect through the lobby and one or more worlds, and finally to the exit survey where they can submit the HIT.

The state of each experiment is encapsulated in [Meteor collections](http://docs.meteor.com/#collections). TurkServer uses the [partitioner](https://github.com/mizzao/meteor-partitioner) package for Meteor to divide up a single Meteor app into different instances that are segregated from one another., and controls the partitioning of each collection based on the flow of participants. Declare your collections to be partitioned with the following client/server code:

```js
Foo = new Mongo.Collection("foo");
TurkServer.partitionCollection(Foo, options);
```

See the [docs for partitioner](https://github.com/mizzao/meteor-partitioner) for an overview of how this works. You can mix partitioned and non-partitioned collections in your Meteor code. Partitioned collections will show different data to participants in each experiment instance, while non-partitioned collections must be separately controlled by your code.

# Batches and Treatments

TurkServer uses the concept of **batches** to logically group instances of experiments together. Each batch limits repeat participation.

Batch controls the assignment of incoming users to **treatments**. Treatments can have structured data which are made available to the front-end app under `TurkServer.treatment()`, making them a useful way to control the display of different parts of the user interface or app behavior. They can be defined for batches, users, or worlds.

Batches and treatments can be viewed and edited from the administration interface.

# Tutorials

TurkServer provides an API for administering tutorials and quizzes for your participants to ensure understanding.

# Exit Surveys

Use an exit survey to collect final data and debrief participants.

# Settings

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
