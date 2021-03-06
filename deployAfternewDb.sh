#!/bin/bash

# A utility to deploy all local tools after renewing database from production.
# I used this script as Acquia is using internal configurations in the following modules:
# 1. APC
# 2. Memcache
# 3. Varnish
#
# Some of the modules like Coder and Stage File Proxy are used in local development.
#
# Run this script after importing new database.
# Travel deployment in local machine.

# Get the settings.php folder.
CONFIGDIR=$(basename $(pwd))

# Purge all the cache first
drush cc all

# Revert all features
drush fra -y

# Run update script
drush updb -y

# Clear the cache again.
drush cc all

# Disable CDN module
drush vset cdn_status 0 -y

# Enable stage file proxy to replace CDN.
drush en stage_file_proxy -y

# Install Varnish.
drush en varnish -y
VARNISHKEY=$(sudo cat /etc/varnish/secret)
drush vset varnish_control_key $VARNISHKEY -y
drush vset varnish_version 3 -y
drush sql-query "INSERT INTO role_permission (rid, permission, module) VALUES (3, 'administer varnish', 'varnish');"

# Install APC module.
drush en apc -y
drush sqlq "INSERT INTO role_permission (rid, permission, module) VALUES (3, 'access apc statistics', 'apc');"

# Install Context UI.
drush en context_ui -y
drush sql-query "INSERT INTO role_permission (rid, permission, module) VALUES (3, 'administer contexts', 'context_ui');"

# Enable Views UI module.
drush en views_ui -y

# Install Memcache Admin.
drush en memcache_admin -y
drush sqlq "INSERT INTO role_permission (rid, permission, module) VALUES (3, 'access slab cachedump', 'memcache_admin');"

# Drop cache_coder table if exists.
drush sqlq "DROP TABLE cache_coder;"

# Install coder review.
drush en coder -y
drush en coder_review -y

# Update temp path
drush vset file_temporary_path /tmp

# Replace Ckeditor with unminified version.
echo -n "Would you like enable Ckeditor unminified library[Yes/No]: "
read CONTINUE
# Execute when the user agree.
if [ "$CONTINUE" == "Yes" ] || [ "$CONTINUE" == "Y" ] || [ "$CONTINUE" == "y" ]; then
  # Let assume that the `php` directory is under settings folder.
  drush php-script --script-path=sites/$CONFIGDIR/php ckeditor_to_unminified
fi

# Clear the cache before exit
drush cc all
