#!/bin/bash

options () {
  while getopts ":s:" optname
    do
      case "$optname" in
        "s")
			if [ "$OPTARG" = "qa" ]; then runscript "qa"
			elif [ "$OPTARG" = "prod" ]; then runscript "prod"
			else 
				echo "Unknown server '$OPTARG'"
				echo "Available options - 'qa' & 'prod'"
			fi  
          ;;
		  
        "?")
			echo "Unknown option '$OPTARG'"
			echo "Use '-s' to specify a server"
          ;;
		  
        ":")
			echo "No argument value for option '$OPTARG'"
			echo "Available options - 'qa' & 'prod'"
          ;;
		  
        *)
			echo "Unknown error while processing options"
          ;;
      esac
    done
}

runscript() {
	sudo /etc/init.d/gitlab stop > ./report.txt 
	cd gitlabhq
	git fetch origin-rim rim-master
	git checkout -f FETCH_HEAD
	build_version="$(cat VERSION).$BUILD_NUMBER"
	echo "$build_version" > VERSION
	bundle install --without development test postgres
	bundle exec rake db:migrate RAILS_ENV=production
	sudo /etc/init.d/gitlab start
	echo "Done >> $1"
}

options "$@"