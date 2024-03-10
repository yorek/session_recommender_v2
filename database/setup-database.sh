 #!/bin/sh

wget https://aka.ms/sqlpackage-linux

unzip sqlpackage-linux -d ./sqlpackage

chmod a+x ./sqlpackage/sqlpackage

./sqlpackage/sqlpackage /version

wget https://github.com/microsoft/go-sqlcmd/releases/download/v1.6.0/sqlcmd-v1.6.0-linux-x64.tar.bz2
tar x -f sqlcmd-v1.6.0-linux-x64.tar.bz2 -C .

wget https://raw.githubusercontent.com/yorek/session_recommender_v2/main/database/setup-database.sql

./sqlcmd -S ${DBSERVER} -d ${DBNAME} -U ${SQLADMIN} -i ./setup-database.sql
