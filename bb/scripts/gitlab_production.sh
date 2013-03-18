#!/bin/bash

sudo /etc/init.d/gitlab stop > ./report.txt
cd gitlabhq
git fetch origin-rim rim-master
git checkout -f FETCH_HEAD
build_version="$(cat VERSION).$BUILD_NUMBER"
echo "$build_version" > VERSION
bundle install --without development test postgres
bundle exec rake db:migrate RAILS_ENV=production
sudo /etc/init.d/gitlab start

echo "Done >> gitlab_production"