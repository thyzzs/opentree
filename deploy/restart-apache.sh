#!/bin/bash

# This script runs as the admin user, which has sudo privileges

OPENTREE_USER=$1
OPENTREE_HOST=$2
OPENTREE_HOME=$(bash <<< "echo ~$OPENTREE_USER")

if apt-cache policy apache2 | egrep -q "Installed: 2.2"; then

echo "This project requires apache 2.4 or higher! Please upgrade apache and try again."
exit 1

else

# Modern code, apache 2.4+

if [ ! -r /etc/apache2/sites-available/opentree.conf ] || \
   ! cmp -s "$OPENTREE_HOME/setup/opentree.conf" /etc/apache2/sites-available/opentree; then
    echo "Installing opentree vhost config"
    sudo cp -p "$OPENTREE_HOME/setup/opentree.conf" /etc/apache2/sites-available/ || "Sudo failed"
fi

if [ ! -r /etc/apache2/sites-available/opentree-ssl ] || \
   ! cmp -s "$OPENTREE_HOME/setup/opentree-ssl.conf" /etc/apache2/sites-available/opentree-ssl.conf; then
    echo "Installing opentree ssl vhost config"
    sudo cp -p "$OPENTREE_HOME/setup/opentree-ssl.conf" /etc/apache2/sites-available/ || "Sudo failed"
    sudo sed -i -e s/SERVERNAME_REPLACEME/$OPENTREE_HOST/ \
      /etc/apache2/sites-available/opentree-ssl.conf  || "Sudo failed"
fi

TMP=/tmp/$$.tmp
sed -e s+/home/opentree+$OPENTREE_HOME+ <"$OPENTREE_HOME/setup/opentree-shared.conf" >$TMP
if [ ! -r /etc/apache2/opentree-shared.conf ] || \
   ! cmp -s $TMP /etc/apache2/opentree-shared.conf; then
    echo "Installing opentree vhosts shared config"
    sudo cp -p $TMP /etc/apache2/opentree-shared.conf || "Sudo failed"
fi
rm $TMP
fi

echo "Restarting apache httpd..."
sudo apache2ctl graceful || "Sudo failed"

# One of these commands hangs after printing "(Re)starting web2py session sweeper..."
# so for now I'm going to disable this code.  See 
# https://github.com/OpenTreeOfLife/opentree/issues/845

if false; then
  echo "(Re)starting web2py session sweeper..."
  # The sessions2trash.py utility script runs in the background, deleting expired
  # sessions every 5 minutes. See documentation at
  #   http://web2py.com/books/default/chapter/29/13/deployment-recipes#Cleaning-up-sessions
  # Find and kill any sweepers that are already running
  sudo pkill -f sessions2trash
  # Now run a fresh instance in the background for each webapp
  sudo nohup python $OPENTREE_HOME/web2py/web2py.py -S opentree -M -R $OPENTREE_HOME/web2py/scripts/sessions2trash.py &
  # NOTE that we allow up to 24 hrs(!) before study-curation sessions will expire
  sudo nohup python $OPENTREE_HOME/web2py/web2py.py -S curator -M -R $OPENTREE_HOME/web2py/scripts/sessions2trash.py --expiration=86400 &
fi
