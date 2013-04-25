#!/bin/bash

start() {
  echo "Denying ssh access to git user"
  cp /etc/ssh/sshd_config /etc/ssh/sshd_config_original
  echo "DenyUsers git" >> /etc/ssh/sshd_config
  /etc/init.d/sshd restart

  echo "Redirecting http to 503_error.html"
  ln -s /etc/nginx/sites-available/maintenance /etc/nginx/sites-enabled/maintenance
  rm /etc/nginx/sites-enabled/gitlab
  /etc/init.d/nginx restart
}

stop() {
  echo "Restoring ssh access to git user"
  cp /etc/ssh/sshd_config_original /etc/ssh/sshd_config
  rm /etc/ssh/sshd_config_original
  /etc/init.d/sshd restart

  echo "Restoring http access to gitlab"
  ln -s /etc/nginx/sites-available/gitlab /etc/nginx/sites-enabled/gitlab
  rm /etc/nginx/sites-enabled/maintenance
  /etc/init.d/nginx restart
}

case "$1" in
    start)   start ;;
    stop)    stop ;;
    *) echo "usage: $0 start|stop" >&2
       exit 1
       ;;
esac
