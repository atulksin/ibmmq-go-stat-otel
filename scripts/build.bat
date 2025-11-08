@echo off
rem Enhanced build script for IBM MQ Statistics Collector (Windows) with Docker BuildKit support
rem Usage: scripts\build.bat [binary|docker|all] [version] [target]

setlocal enabledelayedexpansion

if "%1"=="" (
    set BUILD_TYPE=all
) else (
    set BUILD_TYPE=%1
)

if "%2"=="" (
    set VERSION=dev
) else (
    set VERSION=%2
)

if "%3"=="" (
    set DOCKER_TARGET=final
) else (
    set DOCKER_TARGET=%3
)

for /f %%i in ('powershell -command "Get-Date -Format yyyy-MM-dd_HH:mm:ss"') do set BUILD_TIME=%%i
for /f %%i in ('git rev-parse --short HEAD 2^>nul') do set GIT_COMMIT=%%i
if "!GIT_COMMIT!"=="" set GIT_COMMIT=unknown

set IMAGE_NAME=ibmmq-collector

echo === Building IBM MQ Statistics Collector ===
echo Build type: %BUILD_TYPE%
echo Version: %VERSION%
echo Build time: %BUILD_TIME%
echo Git commit: %GIT_COMMIT%

rem Set build flags
set LDFLAGS=-X main.version=%VERSION% -X main.commit=%GIT_COMMIT% -X main.date=%BUILD_TIME%

if "%BUILD_TYPE%"=="binary" goto BUILD_BINARY
if "%BUILD_TYPE%"=="docker" goto BUILD_DOCKER
if "%BUILD_TYPE%"=="test" goto RUN_TESTS
if "%BUILD_TYPE%"=="all" goto BUILD_ALL

echo Unknown build type: %BUILD_TYPE%
echo Usage: %0 [binary^|docker^|test^|all] [version] [docker_target]
exit /b 1

:BUILD_BINARY
echo === Building cross-platform binaries ===

rem Create build directory
if not exist dist mkdir dist

rem Check for IBM MQ libraries
if exist "C:\Program Files\IBM\MQ" (
    echo IBM MQ libraries found, building with full MQ support
    rem Build with CGO for IBM MQ support
    go build -ldflags "%LDFLAGS%" -o dist\ibmmq-collector.exe .\cmd\collector
) else (
    echo IBM MQ libraries not found, building without CGO
    set CGO_ENABLED=0
    go build -ldflags "%LDFLAGS%" -o dist\ibmmq-collector-no-cgo.exe .\cmd\collector
)

echo Binary build complete!
dir dist\
goto END

:BUILD_DOCKER
echo === Building Docker image with BuildKit ===

rem Enable BuildKit
set DOCKER_BUILDKIT=1
set BUILDKIT_PROGRESS=plain

rem Build Docker image
docker build ^
    --cache-from=%IMAGE_NAME%:cache ^
    --cache-from=%IMAGE_NAME%:latest ^
    --target=%DOCKER_TARGET% ^
    --build-arg VERSION=%VERSION% ^
    --build-arg BUILD_TIME=%BUILD_TIME% ^
    --build-arg GIT_COMMIT=%GIT_COMMIT% ^
    -f Dockerfile.simple ^
    -t %IMAGE_NAME%:%VERSION% ^
    -t %IMAGE_NAME%:latest ^
    .

if %ERRORLEVEL% neq 0 (
    echo Docker build failed!
    exit /b 1
)

echo Docker build completed successfully!
docker images | findstr %IMAGE_NAME%
goto END

:RUN_TESTS
echo === Running tests ===
go test -v .\pkg\config .\pkg\pcf

if %ERRORLEVEL% neq 0 (
    echo Tests failed!
    exit /b 1
)

echo All tests passed!
goto END

:BUILD_ALL
echo === Building everything ===
call :RUN_TESTS
if %ERRORLEVEL% neq 0 exit /b 1

call :BUILD_BINARY
if %ERRORLEVEL% neq 0 exit /b 1

call :BUILD_DOCKER
if %ERRORLEVEL% neq 0 exit /b 1

:END
echo Build process complete!
endlocal