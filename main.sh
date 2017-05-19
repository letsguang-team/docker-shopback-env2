#!/bin/bash

export HOME=/home/$(whoami)

/bin/bash -l -c 'echo RAILS_ENV: $RAILS_ENV'
/bin/bash -l -c 'echo HOME: $HOME'
/bin/bash -l -c 'echo USER: $(whoami)'
/bin/bash -l -c 'cd /var/www/app/current/ && RAILS_ENV=$RAILS_ENV bin/delayed_job start'

sleep infinity
