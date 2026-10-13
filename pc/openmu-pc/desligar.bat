@echo off
cd /d "%~dp0OpenMU\deploy\all-in-one"
docker compose -f docker-compose.yml -f docker-compose.casa.yml down
echo Desligado. Os personagens ficam guardados pra proxima vez.
pause
