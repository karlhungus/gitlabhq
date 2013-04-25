#!/bin/bash
APP_ROOT="/home/git/gitlab"

# Turn off ssh and http access
$APP_ROOT/bb/maintenance/deny_gitlab_access.sh start

# wait 30 seconds for any outstanding requests to be completed
echo "Waiting 30 seconds..."
sleep 30

cd $APP_ROOT 
su --session-command="RAILS_ENV=production bundle exec rake gitlab:backup:create --silent" git

# Turn ssh and http access back on
$APP_ROOT/bb/maintenance/deny_gitlab_access.sh stop
