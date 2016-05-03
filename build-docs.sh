#!/bin/bash
meteor-jsdoc build
cd docs/
DEPLOY_HOSTNAME=galaxy.meteor.com meteor deploy turkserver.meteorapp.com --settings settings.json
