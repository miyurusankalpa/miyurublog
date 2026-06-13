---
title: Enabling IPv6 on Gradle
date: "2026-06-06T10:00z"
description: "Enabling IPv6 on Gradle by setting java.net.preferIPv6Addresses in gradle.properties or shell profile"
draft: false
---

Like every other JVM application, Gradle prefers IPv4 over IPv6 by default. On an IPv6-only network — or any time you want Gradle to reach out over IPv6 — the build can fail to resolve hosts or download dependencies because the Gradle daemon keeps picking IPv4 addresses.

This is especially common on mobile and carrier networks that use NAT64, where IPv4 addresses are synthesized into IPv6 prefixes (e.g., `64:ff9b1::`). If the JVM tries to connect using IPv4 directly instead of going through the NAT64 gateway, the connection fails.

The fix is the same `java.net.preferIPv6Addresses` system property used for [Java and Maven](/enabling-ipv6-on-maven-java/).

## The error

If your build fails with something like this, it means Gradle couldn't download dependencies over IPv6:

```
Caused by: org.gradle.internal.resource.transport.http.HttpRequestException:
  Could not GET 'https://dl.google.com/dl/android/maven2/com/android/tools/build/gradle/8.13.2/gradle-8.13.2.pom'.
```

The stack trace will include lines like `HttpClientHelper.createHttpRequestException` and `HttpResourceAccessor.openResource`. This happens because the JVM falls back to IPv4, which doesn't work on an IPv6-only network or through a NAT64 gateway.

## gradle.properties

Set the property in your project's `gradle.properties`:

```
org.gradle.jvmargs=-Djava.net.preferIPv6Addresses=true
```

This applies to all Gradle invocations in that project.

## Shell profile (permanent fix)

If you keep hitting `HttpRequestException` when Gradle tries to download dependencies over IPv6, add these two environment variables to your shell profile (`~/.bashrc` or `~/.zshrc`):

```bash
export JAVA_TOOL_OPTIONS="-Djava.net.preferIPv6Addresses=true"
export JAVA_OPTS="-Djava.net.preferIPv4Stack=false"
```

Then reload:

```bash
source ~/.bashrc
```

`JAVA_TOOL_OPTIONS` is picked up by every JVM invocation — not just Gradle — so this is the most permanent, system-wide fix. The `JAVA_OPTS` line is a fallback for tools that read that variable instead.

After making changes, stop any running Gradle daemon with `./gradlew --stop`.

<hr>

That's it — Gradle will now prefer IPv6 when resolving and downloading dependencies. If you also need plain Java and Maven to do the same, see [Enabling IPv6 on Java and Maven](/enabling-ipv6-on-maven-java/). 😊
