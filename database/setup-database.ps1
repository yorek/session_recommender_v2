Invoke-WebRequest -Uri https://aka.ms/sqlpackage-windows -OutFile sqlpackage.zip

Expand-Archive .\sqlpackage.zip sqlpackage\

.\sqlpackage\sqlpackage.exe /version