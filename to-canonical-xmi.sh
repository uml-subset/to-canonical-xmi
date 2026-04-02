#!/bin/sh
# to-canonical-xmi — Linux/macOS launcher
# Transforms EA XMI and Eclipse UML XMI to Canonical XMI for UCMIS models.
#
# Usage:
#   ./to-canonical-xmi -s:input.xmi -o:output.xmi [parameter=value ...]
#
# Parameters:
#   generateIds=yes|no              default: yes
#   namespaceURI=<uri>              namespace URI for xmi:uuid generation
#   namespacePrefix=<prefix>        prefix for xmi:id generation
#   qualifiedAssocNames=yes|no      default: yes
#   sourceHasQualifiedNames=yes|no  default: no
#   sourcePackageName=<name>        promote named package to uml:Model root
#   input=ea|eclipse|generic        override input flavour detection
#   eclipseOutput=yes|no            Eclipse UML namespace in output, default: no
#   profilePrefix=<prefix>          namespace prefix of external UML profile
#   profileNamespaceURI=<uri>       override URI for external profile
#
# Examples:
#   ./to-canonical-xmi -s:model.xmi -o:canonical.xmi \
#     namespacePrefix=LIB "namespaceURI=http://example.org/lib"
#
#   ./to-canonical-xmi -s:model.uml -o:canonical.xmi \
#     input=eclipse namespacePrefix=LIB "namespaceURI=http://example.org/lib"
#
#   ./to-canonical-xmi --help

set -e

# Locate the JAR alongside this script
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
JAR="$SCRIPT_DIR/to-canonical-xmi-1.0.0.jar"

if [ ! -f "$JAR" ]; then
    echo "ERROR: JAR not found: $JAR" >&2
    echo "Place to-canonical-xmi-1.0.0.jar in the same directory as this script." >&2
    exit 1
fi

# Check Java is available
if ! command -v java > /dev/null 2>&1; then
    echo "ERROR: Java not found. Java 11 or later is required." >&2
    echo "Install Java from https://adoptium.net or your package manager." >&2
    exit 1
fi

# Check Java version >= 11
JAVA_VERSION=$(java -version 2>&1 | head -1 | sed 's/.*version "\([0-9]*\).*/\1/')
if [ -n "$JAVA_VERSION" ] && [ "$JAVA_VERSION" -lt 11 ] 2>/dev/null; then
    echo "ERROR: Java 11 or later is required (found Java $JAVA_VERSION)." >&2
    exit 1
fi

exec java -jar "$JAR" "$@"
