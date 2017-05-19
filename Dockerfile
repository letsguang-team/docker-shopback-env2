# -- ubuntu-rvm -------------------------------------------------------------------------------------------------
FROM ubuntu:trusty
MAINTAINER Martin Chan <osiutino@gmail.com>

USER root

# Update
RUN apt-get update
RUN apt-get upgrade -y
RUN apt-get install curl -y

# Setup environment
RUN locale-gen en_US.UTF-8
ENV LANG en_US.UTF-8
ENV LANGUAGE en_US:en
ENV LC_ALL en_US.UTF-8

# Setup User
RUN useradd --home /home/worker -M worker -K UID_MIN=10000 -K GID_MIN=10000 -s /bin/bash
RUN mkdir /home/worker
RUN chown worker:worker /home/worker
RUN adduser worker sudo
RUN echo 'worker ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers

USER worker

ENV RUBY_VERSION 2.3.1

# Install RVM
RUN gpg --keyserver hkp://keys.gnupg.net --recv-keys 409B6B1796C275462A1703113804BB82D39DC0E3
RUN \curl -sSL https://get.rvm.io | bash -s stable
RUN /bin/bash -l -c 'source ~/.rvm/scripts/rvm'

# Install Ruby
RUN /bin/bash -l -c 'rvm requirements'
RUN /bin/bash -l -c 'rvm install $RUBY_VERSION'
RUN /bin/bash -l -c 'rvm use $RUBY_VERSION --default'
RUN /bin/bash -l -c 'rvm rubygems current'

# Install bundler
RUN /bin/bash -l -c 'gem install bundler --no-doc --no-ri'

# -- ubuntu-rails -------------------------------------------------------------------------------------------------

USER worker

ENV RAILS_VERSION 5.0.1

RUN /bin/bash -l -c 'gem install rails --version=$RAILS_VERSION --no-doc --no-ri'

# -- ubuntu-rails-apache-passenger -------------------------------------------------------------------------------------------------


USER root

# Update
RUN apt-get update

# apache setup ---------------------------------------------------

# Apache
RUN apt-get -y install apache2 apache2-mpm-worker

RUN echo 'sudo /usr/sbin/apachectl start' >> /etc/bash.bashrc

RUN apachectl restart

# passenger dependencies --------------------------------------------- >>

RUN apt-get install -y nodejs --no-install-recommends

# Curl development headers with SSL support
RUN apt-get install -y libcurl4-openssl-dev

# Apache 2 development headers
RUN apt-get install -y apache2-threaded-dev

# Apache Portable Runtime (APR) development headers
RUN apt-get install -y libapr1-dev

# Apache Portable Runtime Utility (APU) development headers
RUN apt-get install -y libaprutil1-dev

# install passenger ---------------------------------------------------- >>

USER worker

ENV PASSENGER_VERSION 5.0.30

RUN /bin/bash -l -c 'gem install passenger --version $PASSENGER_VERSION --no-rdoc --no-ri'
RUN /bin/bash -l -c 'passenger-install-apache2-module --auto'

# config passenger ----------------------------------------------------- >>

USER root

ENV RUBY_VERSION 2.3.1
ENV PASSENGER_VERSION 5.0.30

RUN echo "LoadModule passenger_module /home/worker/.rvm/gems/ruby-$RUBY_VERSION/gems/passenger-$PASSENGER_VERSION/buildout/apache2/mod_passenger.so" > /etc/apache2/mods-available/passenger.load

RUN echo "<IfModule mod_passenger.c>\n \
 PassengerRoot /home/worker/.rvm/gems/ruby-$RUBY_VERSION/gems/passenger-$PASSENGER_VERSION\n \
 PassengerDefaultRuby /home/worker/.rvm/gems/ruby-$RUBY_VERSION/wrappers/ruby\n \
</IfModule>" > /etc/apache2/mods-available/passenger.conf

RUN a2enmod passenger

RUN apachectl restart

# config virtual host ------------------------------------------------ >>

ADD 000-default.conf /etc/apache2/sites-enabled/000-default.conf

RUN mkdir -p /var/www/app/current/public
RUN echo OK > /var/www/app/current/public/index.html
RUN chown worker:worker -R /var/www/

RUN apachectl restart

# ----------------------------------------------------------------------

# clean apt caches
RUN rm -rf /var/lib/apt/lists/*

# ----------------------------------------------------------------------

USER worker

# -- ubuntu-rails-apache-passenger-ssh -------------------------------------------------------------------------------------------------

USER root

RUN apt-get update
RUN apt-get -y install openssh-client openssh-server
RUN apt-get -y install git-core

# -----------------------------------------------------------

RUN touch /etc/ssh/ssh_host_rsa_key
RUN echo 'sudo service ssh start' >> /etc/bash.bashrc
RUN service ssh start

# -----------------------------------------------------------
RUN mkdir /home/worker/.ssh
ADD ssh/* /home/worker/.ssh/
RUN chmod 755 /home/worker/.ssh
RUN chmod 400 /home/worker/.ssh/id_rsa
RUN chown -R worker:worker /home/worker/.ssh
# -----------------------------------------------------------

USER worker
WORKDIR /home/worker/

# -- shopback-env -------------------------------------------------------------------------------------------------

USER root

RUN apt-get update
RUN apt-get install nodejs -y
RUN apt-get install libmysqlclient-dev -y
RUN apt-get install libyaml-dev -y
RUN apt-get install imagemagick -y
RUN apt-get install build-essential -y
RUN apt-get install vim -y
RUN apt-get install mysql-client -y

# -----------------------------------------------------------

RUN a2enmod headers
RUN a2enmod proxy
RUN a2enmod proxy_connect
RUN a2enmod proxy_http
RUN a2enmod rewrite
RUN a2enmod socache_shmcb
RUN a2enmod ssl

# - REMOVE MAGIC  -------------------------------------------

RUN gpasswd -d worker sudo

RUN sed -i '$ d' /etc/sudoers

RUN head -n -2 /etc/bash.bashrc > /etc/bash.bashrc

# -----------------------------------------------------------

RUN echo "Asia/Hong_Kong" > /etc/timezone; dpkg-reconfigure -f noninteractive tzdata

RUN apt-get install  -y supervisor

COPY main.sh /home/worker/

RUN chown worker:worker /home/worker/main.sh

# ----------------------------------------------------------

RUN mkdir -p /var/log/supervisor

COPY supervisord.conf /etc/supervisor/conf.d/supervisord.conf

WORKDIR /home/worker/

CMD ["/usr/bin/supervisord"]

ENV REFRESHED_AT 2017-05-19
