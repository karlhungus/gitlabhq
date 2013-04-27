#!/bin/bash

# $1 is the timestamp of the backup you wish to restore, in seconds.
# You can find that timestamp prepended to the backup filename.
# To restore from a backup file named 1366951287_gitlab_backup.tar
# execute the script with 1366951287 as the argument

# add /usr/local/bin since that is where the ruby, gem and bundler executables are
PATH=$PATH:/usr/local/bin

APP_ROOT="/home/git/gitlab"

# Turn off ssh and http access
$APP_ROOT/bb/maintenance/deny_gitlab_access.sh start

# wait 30 seconds for any outstanding requests to be completed
echo "Waiting 30 seconds..."
sleep 30


cd $APP_ROOT
su --session-command="RAILS_ENV=production bundle exec rake gitlab:backup:restore BACKUP=$1 --silent" git

# Turn ssh and http access back on
$APP_ROOT/bb/maintenance/deny_gitlab_access.sh stop