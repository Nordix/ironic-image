#!/usr/bin/bash

export IRONIC_DEPLOYMENT="API"

. /bin/configure-ironic.sh

if [[ $IRONIC_API_BEHIND_WSGI == "false" ]]
then
  exec /usr/bin/ironic-api --config-file /usr/share/ironic/ironic-dist.conf ${IRONIC_CONFIG_OPTIONS}
else
  python3 -c 'import os; import sys; import jinja2; sys.stdout.write(jinja2.Template(sys.stdin.read()).render(env=os.environ))' < /etc/httpd-ironic-api.conf.j2 > /etc/httpd/conf.d/ironic.conf
  sed -i "/Listen 80/c\#Listen 80" /etc/httpd/conf/httpd.conf
  exec /usr/sbin/httpd -DFOREGROUND
fi

