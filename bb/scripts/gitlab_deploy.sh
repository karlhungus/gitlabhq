#!/bin/bash

# This should run under the git account on the destination server
# Starts in the /home/git/ directory

sudo /etc/init.d/gitlab stop
cd /home/git/gitlab
git fetch origin-rim rim-master
git checkout -f FETCH_HEAD
bundle install --without development test postgres
bundle exec rake db:migrate RAILS_ENV=production
sudo /etc/init.d/gitlab start
