#!/usr/bin/bash
PATH=$PATH:/usr/sbin/
DATADIR="/var/lib/mysql"
MARIADB_PASSWORD=${MARIADB_PASSWORD:-"change_me"}
MARIADB_CONF_FILE="/etc/my.cnf.d/mariadb-server.cnf"

ln -sf /proc/self/fd/1 /var/log/mariadb/mariadb.log

if [ ! -d "${DATADIR}/mysql" ]; then
    crudini --set "$MARIADB_CONF_FILE" mysqld max_connections 64
    crudini --set "$MARIADB_CONF_FILE" mysqld max_heap_table_size 1M
    crudini --set "$MARIADB_CONF_FILE" mysqld innodb_buffer_pool_size 5M
    crudini --set "$MARIADB_CONF_FILE" mysqld innodb_log_buffer_size 512K

    # Config MariaDB to enable TLS
    if [[  ${IRONIC_TLS_SETUP} == "true" ]]
    then
      if [[ ! -a "/certs/mariadb/tls.crt" ]]
      then
        echo "Certificate file not found "
        exit 0
      fi

      if [[ ! -a "/certs/mariadb/tls.key" ]]
      then
        echo "Private key not found"
        exit 0
      fi
      mkdir -p "${DATADIR}/certs/"
      cp "/certs/mariadb" "${DATADIR}/certs/" -r
      crudini --set "$MARIADB_CONF_FILE" mariadb-10.3 ssl on
      crudini --set "$MARIADB_CONF_FILE" mariadb-10.3 ssl_cert "${DATADIR}/certs/mariadb/tls.crt"
      crudini --set "$MARIADB_CONF_FILE" mariadb-10.3 ssl_key "${DATADIR}/certs/mariadb/tls.key"

      # If mTLS is enabled -> Uncomment the below section
        # if [[ ! -a "/certs/ca/mariadb/tls.crt" ]]
        # then
        #   echo "CA certificate not found"
        #   exit 0
        # fi
        # mkdir -p "${DATADIR}/certs/ca/"
        # cp "certs/ca/mariadb" "${DATADIR}/certs/ca/" -r
        # crudini --set "$MARIADB_CONF_FILE" mariadb-10.3 ssl_ca "${DATADIR}/certs/ca/mariadb/tls.crt"

    fi

    mysql_install_db --datadir="$DATADIR"

    chown -R mysql "$DATADIR"

    cat > /tmp/configure-mysql.sql <<-EOSQL
DELETE FROM mysql.user ;
CREATE USER 'ironic'@'localhost' identified by '${MARIADB_PASSWORD}' ;
GRANT ALL on *.* TO 'ironic'@'localhost' WITH GRANT OPTION ;
DROP DATABASE IF EXISTS test ;
CREATE DATABASE IF NOT EXISTS  ironic ;
FLUSH PRIVILEGES ;
EOSQL

    # mysqld_safe closes stdout/stderr if no bash options are set ($- == '')
    # turn on tracing to prevent this
    exec bash -x /usr/bin/mysqld_safe --init-file /tmp/configure-mysql.sql
else
    exec bash -x /usr/bin/mysqld_safe
fi
