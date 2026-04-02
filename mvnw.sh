#!/bin/sh
# ----------------------------------------------------------------------------
# Licensed to the Apache Software Foundation (ASF) under one
# or more contributor license agreements.  See the NOTICE file
# distributed with this work for additional information
# regarding copyright ownership.  The ASF licenses this file
# to you under the Apache License, Version 2.0 (the
# "License"); you may not use this file except in compliance
# with the License.  You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing,
# software distributed under the License is distributed on an
# "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
# KIND, either express or implied.  See the License for the
# specific language governing permissions and limitations
# under the License.
# ----------------------------------------------------------------------------

# ----------------------------------------------------------------------------
# Apache Maven Wrapper startup script, version 3.2.0
# ----------------------------------------------------------------------------

# If JAVA_HOME is set, use it; otherwise assume java is on the PATH
if [ -n "$JAVA_HOME" ]; then
    JAVACMD="$JAVA_HOME/bin/java"
else
    JAVACMD="java"
fi

if ! command -v "$JAVACMD" > /dev/null 2>&1; then
    echo "Error: JAVA_HOME is not set and java is not on the PATH." >&2
    echo "  Please set the JAVA_HOME variable to the Java installation directory." >&2
    exit 1
fi

# Resolve the script's own directory (handles symlinks)
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
MAVEN_WRAPPER_PROPERTIES="$SCRIPT_DIR/.mvn/wrapper/maven-wrapper.properties"

if [ ! -f "$MAVEN_WRAPPER_PROPERTIES" ]; then
    echo "Error: Cannot find $MAVEN_WRAPPER_PROPERTIES" >&2
    exit 1
fi

# Read the distribution URL
DISTRIBUTION_URL=$(grep "^distributionUrl" "$MAVEN_WRAPPER_PROPERTIES" | sed 's/distributionUrl=//' | tr -d '\r\n')

if [ -z "$DISTRIBUTION_URL" ]; then
    echo "Error: distributionUrl not found in $MAVEN_WRAPPER_PROPERTIES" >&2
    exit 1
fi

# Compute the distribution name and local cache path
DIST_FILENAME=$(basename "$DISTRIBUTION_URL")
DIST_NAME="${DIST_FILENAME%.zip}"
WRAPPER_DIR="$HOME/.m2/wrapper/dists/$DIST_NAME"

# The Maven version directory inside the zip (strip -bin suffix)
MAVEN_VERSION=$(echo "$DIST_NAME" | sed 's/apache-maven-//' | sed 's/-bin//')
MAVEN_HOME="$WRAPPER_DIR/apache-maven-$MAVEN_VERSION"
MVN_CMD="$MAVEN_HOME/bin/mvn"

# Download and unpack if not already cached
if [ ! -x "$MVN_CMD" ]; then
    echo "Downloading Maven $MAVEN_VERSION ..."
    mkdir -p "$WRAPPER_DIR"
    DIST_ZIP="$WRAPPER_DIR/$DIST_FILENAME"

    if command -v curl > /dev/null 2>&1; then
        curl -fsSL "$DISTRIBUTION_URL" -o "$DIST_ZIP"
    elif command -v wget > /dev/null 2>&1; then
        wget -q "$DISTRIBUTION_URL" -O "$DIST_ZIP"
    else
        echo "Error: curl or wget required to download Maven." >&2
        exit 1
    fi

    echo "Extracting Maven ..."
    unzip -q "$DIST_ZIP" -d "$WRAPPER_DIR"
    rm -f "$DIST_ZIP"
    chmod +x "$MVN_CMD"
    echo "Maven $MAVEN_VERSION installed to $MAVEN_HOME"
fi

exec "$MVN_CMD" "$@"
