---
title: Enabling IPv6 on Maven and Java
date: "2021-11-29T22:49z"
description: "Enabling IPv6 on Maven and Java"
draft: false
---

With IPv6 adoption being increased due to IPv4 scarcity and more providers like AWS and Hetzner moving on to IPv6 only networks, it is important to know that your app supports and uses the IPv6.

Java as it turns out comes out of the box with IPv6 disabled. Here are some steps that you can follow to enable IPv6 on you java app.

# Maven

Maven which is heavily used to build java projects needs a few steps to enable IPv6.
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

