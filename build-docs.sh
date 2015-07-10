#!/bin/bash
meteor-jsdoc build
cd docs/
meteor deploy turkserver.meteor.com
