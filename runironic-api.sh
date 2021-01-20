#!/usr/bin/bash

export IRONIC_DEPLOYMENT="API"

. /bin/configure-ironic.sh

# Wait for ironic to load all expected drivers
# the DB query returns the number of unique hardware_type in the conductor_hardware_interfaces table
CONF_DRIVERS=$(crudini --get /etc/ironic/ironic.conf DEFAULT enabled_hardware_types | tr ',' '\n' | wc -l)
while true ; do
  DB_DRIVERS=$(mysql -p$MARIADB_PASSWORD -u ironic -h 127.0.0.1 ironic -e 'select count( DISTINCT hardware_type) from conductor_hardware_interfaces' -B -s --ssl || echo 0)
  [ "$DB_DRIVERS" -ge "$CONF_DRIVERS" ] && break
  echo "Waiting for $CONF_DRIVERS expected drivers"
  sleep 5
done

. /bin/configure-httpd-ipa.sh  

python3 -c 'import os; import sys; import jinja2; sys.stdout.write(jinja2.Template(sys.stdin.read()).render(env=os.environ))' < /etc/httpd-ironic-api.conf.j2 > /etc/httpd/conf.d/ironic.conf
sed -i "/Listen 80/c\#Listen 80" /etc/httpd/conf/httpd.conf
exec /usr/sbin/httpd -DFOREGROUND

