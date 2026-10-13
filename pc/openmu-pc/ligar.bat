@echo off
cd /d "%~dp0"
where docker >nul 2>nul || (echo Docker nao encontrado. Instale o Docker Desktop e abra ele antes. & pause & exit /b 1)
where git >nul 2>nul || (echo Git nao encontrado. Instale o Git for Windows. & pause & exit /b 1)
if not exist OpenMU git clone --depth 1 https://github.com/MUnique/OpenMU.git
copy /y docker-compose.casa.yml OpenMU\deploy\all-in-one\ >nul
set ENV=OpenMU\deploy\all-in-one\.env
if exist %ENV% goto subir
echo Primeira vez: escolha a senha do painel do servidor (usuario: murilo).
set /p SENHA=Senha: 
echo OPENMU_ADMIN_USER=murilo> %ENV%
echo OPENMU_ADMIN_PASSWORD=%SENHA%>> %ENV%
:subir
cd OpenMU\deploy\all-in-one
docker compose -f docker-compose.yml -f docker-compose.casa.yml pull
docker compose -f docker-compose.yml -f docker-compose.casa.yml up -d --no-build
echo.
echo Pronto. Painel: http://localhost/   Cliente: 127.127.127.127 porta 44405
echo Na primeira vez o banco leva uns minutos pra ficar pronto.
pause
