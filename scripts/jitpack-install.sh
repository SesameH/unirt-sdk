#!/usr/bin/env bash
# Copyright (c) 2026 Peter Huang.
# SPDX-License-Identifier: BSD-3-Clause
#
# JitPack entry point (see jitpack.yml): instead of rebuilding the AAR —
# which would need the NDK plus the closed-source prebuilt libraries — it
# downloads the AAR already attached to this repo's Release for the tag
# being built and installs it into the local Maven repo, where JitPack
# picks it up. Consumers then just add the JitPack repo and depend on
# com.github.SesameH:unirt-sdk:<tag>.
set -euo pipefail

# JitPack exports VERSION as the git ref it is building (e.g. v0.1.0).
: "${VERSION:?VERSION not set — this script is meant to run on JitPack}"

curl -fL -o unirt-android.aar \
  "https://github.com/SesameH/unirt-sdk/releases/download/${VERSION}/unirt-android.aar"

# install:install-file with -DgeneratePom would lose the runtime deps, so
# ship a minimal POM: the Kotlin API surface needs the stdlib and exposes
# kotlinx.coroutines.flow.Flow (versions matched to android/build.gradle.kts).
cat > unirt-pom.xml <<EOF
<project xmlns="http://maven.apache.org/POM/4.0.0">
  <modelVersion>4.0.0</modelVersion>
  <groupId>com.github.SesameH</groupId>
  <artifactId>unirt-sdk</artifactId>
  <version>${VERSION}</version>
  <packaging>aar</packaging>
  <name>UniRT Android</name>
  <licenses><license><name>BSD-3-Clause</name></license></licenses>
  <dependencies>
    <dependency>
      <groupId>org.jetbrains.kotlin</groupId>
      <artifactId>kotlin-stdlib</artifactId>
      <version>2.0.21</version>
      <scope>compile</scope>
    </dependency>
    <dependency>
      <groupId>org.jetbrains.kotlinx</groupId>
      <artifactId>kotlinx-coroutines-core</artifactId>
      <version>1.9.0</version>
      <scope>compile</scope>
    </dependency>
  </dependencies>
</project>
EOF

mvn --batch-mode install:install-file \
  -Dfile=unirt-android.aar -DpomFile=unirt-pom.xml
