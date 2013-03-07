#!/bin/bash
source ~/.profile                                                      #ensure the necessary env variables are set
export rvm_path=""            
[[ -s "$HOME/.rvm/scripts/rvm" ]] && source "$HOME/.rvm/scripts/rvm"   #ensure everyone is using the same ruby 
rvm use --create ruby-1.9.3@gitlabhq
#rvm --force gemset empty                                              #this can likely be safely commented out to shorten build time
gem install bundler --no-rdoc --no-ri
gem install rspec rspec-rails rspec-rails-matchers
bundle install

cp config/database.yml.mysql config/database.yml
cp config/gitlab.yml.example config/gitlab.yml

#echo "<<<<DEBUG>>>>>"
#env
#echo $PATH
#python -V
#which ruby
#which gem
#which rake
#which bundle
#which rspec
#rspec -v
#bundle exec rspec -v --trace
#rvm gemdir
#bundle exec rake -V --trace
#echo "<<<END DEBUG>>>>"

#setup
bundle exec rake db:create RAILS_ENV=test
bundle exec rake db:migrate RAILS_ENV=test
bundle exec rake db:seed_fu RAILS_ENV=test
#sh -e /usr/bin/xvfb start                                             #No longer needed as Jenkins is starting and stopping xvfb as part of build

build_version="$(cat VERSION).$BUILD_NUMBER"
echo "$build_version" > VERSION

#tests
bundle exec spinach
bundle_spinach=$?

bundle exec rspec spec
bundle_rspec=$?

if  [ $bundle_spinach -gt 0 ] ; then
  echo "Failed on spinach tests"
  exit $bundle_spinach
fi

if  [ $bundle_rspec -gt 0 ] ; then
  echo "Failed rspec tests"
  exit $bundle_rspec
fi
