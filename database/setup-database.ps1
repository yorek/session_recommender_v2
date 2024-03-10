Invoke-WebRequest -Uri https://aka.ms/sqlpackage-linux -OutFile sqlpackage.zip

Expand-Archive ./sqlpackage.zip sqlpackage/

chmod a+x ./sqlpackage/sqlpackage

./sqlpackage/sqlpackage /version

Invoke-WebRequest -Uri https://raw.githubusercontent.com/yorek/session_recommender_v2/main/database/session_recommender_v2.dacpac -OutFile session_recommender_v2.dacpac


SqlPackage /Action:Publish /SourceFile:"C:\AdventureWorksLT.dacpac" \
    /TargetConnectionString:"Server=tcp:{yourserver}.database.windows.net,1433;Initial Catalog=AdventureWorksLT;Persist Security Info=False;User ID=sqladmin;Password={your_password};MultipleActiveResultSets=False;Encrypt=True;TrustServerCertificate=False;Connection Timeout=30;"
