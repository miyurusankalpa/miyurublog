---
title: Enabling IPv6 on Java and Maven
date: "2021-11-29T22:49z"
updated: "2026-05-01T17:43z"
description: "How to enable IPv6 support on Java and Maven"
draft: false
---

With IPv6 adoption being increased due to IPv4 scarcity and more providers like AWS and Hetzner moving on to IPv6 only networks, it is important to know that your app supports and uses the IPv6.

Java as it turns out comes out of the box with IPv6 disabled. Here are some steps that you can follow to enable IPv6 on you java app.

# Maven

Maven which is heavily used to build java projects supports IPv6 on the default central repository now.

To make Maven always prefer IPv6, you can configure it once instead of passing flags every time.

Create or edit the file `.mvn/jvm.config` in your project and add:
-Djava.net.preferIPv6Addresses=true

    -Djava.net.preferIPv6Addresses=true

This will automatically apply the setting to all Maven commands.

Alternatively, you can set it globally using an environment variable:

    export MAVEN_OPTS="-Djava.net.preferIPv6Addresses=true"


This ensures all Maven builds prefer IPv6 without additional flags.

## Old (Deprecated)

The default maven repo does not support IPv6 [yet](https://issues.apache.org/jira/browse/INFRA-22061).  However you can use IPv6 enabled repo *ipv6.repo1.maven.org* instead.

Open `~.m2/settings.xml` and add the following to change the default central repo.

```xml
<settings>
  <mirrors>
    <mirror>
      <id>maven-ipv6</id>
      <name>IPv6 Mirror Repository</name>
      <url>https://ipv6.repo1.maven.org/maven2</url>
      <mirrorOf>central</mirrorOf>
    </mirror>
  </mirrors>
</settings>
```

and when running mvn command append the following to use IPv6.

    -Djava.net.preferIPv6Addresses=true

# Java

For Java Applications you can enable IPv6 by adding `-Djava.net.preferIPv6Addresses=true` when running for a command line as with maven.

Or add the `preferIPv6Addresses` on the system property in the app itself.

```java
System.setProperty("java.net.preferIPv6Addresses", "true");
```

This will make the application use IPv6 when available.

