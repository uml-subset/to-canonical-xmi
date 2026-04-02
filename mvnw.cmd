@echo off
@REM Maven Wrapper Script (Windows)
@REM Generated for to-canonical-xmi — does not require maven-wrapper.jar
@REM Downloads the Maven distribution on first use and caches it in %USERPROFILE%\.m2\wrapper\dists

setlocal enabledelayedexpansion

set "SCRIPT_DIR=%~dp0"
set "PROPERTIES_FILE=%SCRIPT_DIR%.mvn\wrapper\maven-wrapper.properties"

if not exist "%PROPERTIES_FILE%" (
    echo ERROR: Cannot find %PROPERTIES_FILE% >&2
    exit /b 1
)

@REM Read distributionUrl from properties file
set "DISTRIBUTION_URL="
for /f "tokens=2 delims==" %%i in ('findstr /b "distributionUrl" "%PROPERTIES_FILE%"') do (
    set "DISTRIBUTION_URL=%%i"
)

if "!DISTRIBUTION_URL!"=="" (
    echo ERROR: distributionUrl not found in %PROPERTIES_FILE% >&2
    exit /b 1
)

@REM Derive distribution name from URL
for %%f in (!DISTRIBUTION_URL!) do set "DIST_ZIP_NAME=%%~nxf"
set "DIST_NAME=%DIST_ZIP_NAME:.zip=%"

@REM Extract version: apache-maven-3.9.6-bin -> 3.9.6
set "MAVEN_VERSION=%DIST_NAME:apache-maven-=%"
set "MAVEN_VERSION=%MAVEN_VERSION:-bin=%"

set "DIST_CACHE_DIR=%USERPROFILE%\.m2\wrapper\dists\%DIST_NAME%"
set "MAVEN_HOME=%DIST_CACHE_DIR%\apache-maven-%MAVEN_VERSION%"
set "MVN_CMD=%MAVEN_HOME%\bin\mvn.cmd"

if not exist "%MVN_CMD%" (
    echo Downloading Maven from !DISTRIBUTION_URL!
    if not exist "%DIST_CACHE_DIR%" mkdir "%DIST_CACHE_DIR%"
    set "DIST_ZIP=%DIST_CACHE_DIR%\%DIST_ZIP_NAME%"

    powershell -Command "& { [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; Invoke-WebRequest -Uri '!DISTRIBUTION_URL!' -OutFile '!DIST_ZIP!' }"
    if errorlevel 1 (
        echo ERROR: Failed to download Maven. Check your internet connection. >&2
        exit /b 1
    )

    echo Unpacking Maven...
    powershell -Command "Expand-Archive -Path '!DIST_ZIP!' -DestinationPath '!DIST_CACHE_DIR!' -Force"
    del "!DIST_ZIP!"
    echo Maven installed to !MAVEN_HOME!
)

if not exist "%MVN_CMD%" (
    echo ERROR: Maven executable not found at %MVN_CMD% >&2
    echo Try deleting %DIST_CACHE_DIR% and re-running. >&2
    exit /b 1
)

"%MVN_CMD%" -f "%SCRIPT_DIR%pom.xml" %*
