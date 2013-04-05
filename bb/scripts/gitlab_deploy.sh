#!/bin/bash

# QA and PRODUCTION
sudo /etc/init.d/gitlab stop
cd gitlabhq
git fetch origin-rim rim-master
git checkout -f FETCH_HEAD
bundle install --without development test postgres
bundle exec rake db:migrate RAILS_ENV=production
sudo /etc/init.d/gitlab start

