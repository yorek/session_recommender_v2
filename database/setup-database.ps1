Invoke-WebRequest -Uri https://aka.ms/sqlpackage-linux -OutFile sqlpackage.zip

Expand-Archive ./sqlpackage.zip sqlpackage/

chmod a+x ./sqlpackage/sqlpackage

./sqlpackage/sqlpackage /version

Invoke-WebRequest -Uri https://github.com/yorek/session_recommender_v2/raw/main/database/session_recommender_v2.dacpac -OutFile session_recommender_v2.dacpac

./sqlpackage/sqlpackage /Action:Publish /SourceFile:"session_recommender_v2.dacpac" /TargetDatabaseName:${DBNAME} /TargetServerName:${DBSERVER} /TargetUser:${SQLADMIN} /TargetPassword:${SQLCMDPASSWORD}
