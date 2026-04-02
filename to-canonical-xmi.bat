@echo off
@REM to-canonical-xmi.bat — Windows launcher
@REM Transforms EA XMI and Eclipse UML XMI to Canonical XMI for UCMIS models.
@REM
@REM Usage:
@REM   to-canonical-xmi -s:input.xmi -o:output.xmi [parameter=value ...]
@REM
@REM Parameters:
@REM   generateIds=yes^|no              default: yes
@REM   namespaceURI=^<uri^>              namespace URI for xmi:uuid generation
@REM   namespacePrefix=^<prefix^>        prefix for xmi:id generation
@REM   qualifiedAssocNames=yes^|no      default: yes
@REM   sourceHasQualifiedNames=yes^|no  default: no
@REM   sourcePackageName=^<n^>       promote named package to uml:Model root
@REM   input=ea^|eclipse^|generic        override input flavour detection
@REM   eclipseOutput=yes^|no            Eclipse UML namespace in output, default: no
@REM   profilePrefix=^<prefix^>          namespace prefix of external UML profile
@REM   profileNamespaceURI=^<uri^>       override URI for external profile
@REM
@REM Examples:
@REM   to-canonical-xmi -s:model.xmi -o:canonical.xmi ^
@REM     namespacePrefix=LIB "namespaceURI=http://example.org/lib"
@REM
@REM   to-canonical-xmi -s:model.uml -o:canonical.xmi ^
@REM     input=eclipse namespacePrefix=LIB "namespaceURI=http://example.org/lib"
@REM
@REM   to-canonical-xmi --help

setlocal

@REM Locate the JAR alongside this script
set "SCRIPT_DIR=%~dp0"
set "JAR=%SCRIPT_DIR%to-canonical-xmi-1.0.0.jar"

if not exist "%JAR%" (
    echo ERROR: JAR not found: %JAR% >&2
    echo Place to-canonical-xmi-1.0.0.jar in the same directory as this script. >&2
    exit /b 1
)

@REM Check Java is available
where java >nul 2>&1
if errorlevel 1 (
    echo ERROR: Java not found. Java 11 or later is required. >&2
    echo Install Java from https://adoptium.net >&2
    exit /b 1
)

@REM Check Java version >= 11
for /f "tokens=3 delims= " %%v in ('java -version 2^>^&1 ^| findstr /i "version"') do (
    set "JAVA_VER_RAW=%%v"
)
set "JAVA_VER_RAW=%JAVA_VER_RAW:"=%"
for /f "tokens=1 delims=." %%m in ("%JAVA_VER_RAW%") do set "JAVA_MAJOR=%%m"
if defined JAVA_MAJOR (
    if %JAVA_MAJOR% LSS 11 (
        echo ERROR: Java 11 or later is required ^(found Java %JAVA_MAJOR%^). >&2
        exit /b 1
    )
)

java -jar "%JAR%" %*
