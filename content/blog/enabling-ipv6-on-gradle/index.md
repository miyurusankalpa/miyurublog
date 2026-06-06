---
title: Enabling IPv6 on Gradle
date: "2026-06-06T10:00z"
description: "Enabling IPv6 on Gradle by setting java.net.preferIPv6Addresses in the vmoptions file"
draft: false
---

Like every other JVM application, Gradle prefers IPv4 over IPv6 by default. On an IPv6-only network — or any time you want Gradle to reach out over IPv6 — the build can fail to resolve hosts or download dependencies because the Gradle daemon keeps picking IPv4 addresses.

The fix is the same `java.net.preferIPv6Addresses` system property used for [Java and Maven](/enabling-ipv6-on-maven-java/). When you run Gradle from IntelliJ IDEA or Android Studio, the cleanest place to set it is the IDE's `vmoptions` file.

## The vmoptions file

Add the following line to the vmoptions file:

```
-Djava.net.preferIPv6Addresses=true
```

If the file already contains `-Djava.net.preferIPv4Stack=true` or `-Djava.net.preferIPv4Addresses=true`, remove that line so it does not override the IPv6 preference.

The easiest way to open the right file is from inside the IDE: **Help → Edit Custom VM Options**. This creates the file in the correct location for your platform and opens it for editing. If you would rather edit it directly, the default locations are below.

For IntelliJ IDEA the file is named `idea.vmoptions`; for Android Studio it is `studio.vmoptions`. Replace `<version>` with the version you have installed.

### Linux

IntelliJ IDEA:

```
~/.config/JetBrains/IntelliJIdea<version>/idea.vmoptions
```

Android Studio:

```
~/.config/Google/AndroidStudio<version>/studio.vmoptions
```

### macOS

IntelliJ IDEA:

```
~/Library/Application Support/JetBrains/IntelliJIdea<version>/idea.vmoptions
```

Android Studio:

```
~/Library/Application Support/Google/AndroidStudio<version>/studio.vmoptions
```

### Windows

IntelliJ IDEA:

```
%APPDATA%\JetBrains\IntelliJIdea<version>\idea.vmoptions
```

Android Studio:

```
%APPDATA%\Google\AndroidStudio<version>\studio.vmoptions
```

### Resolving the version automatically

If you have several versions installed — or just don't want to look up the version number — replace `<version>` with a `*` wildcard and let the shell find the file for you. The one-liners below append the option to the most recently used version's vmoptions file.

> ⚠️ These commands append the line without checking, so running one twice adds the option twice. Run it once, or open the file afterwards to confirm there is only a single `preferIPv6Addresses` line.

#### IntelliJ IDEA

Linux:

```bash
echo "-Djava.net.preferIPv6Addresses=true" >> "$(ls -dt ~/.config/JetBrains/IntelliJIdea*/ | head -1)idea.vmoptions"
```

macOS:

```bash
echo "-Djava.net.preferIPv6Addresses=true" >> "$(ls -dt ~/Library/Application\ Support/JetBrains/IntelliJIdea*/ | head -1)idea.vmoptions"
```

Windows (PowerShell):

```powershell
Add-Content (Get-ChildItem "$env:APPDATA\JetBrains\IntelliJIdea*\idea.vmoptions" | Sort-Object LastWriteTime | Select-Object -Last 1).FullName "-Djava.net.preferIPv6Addresses=true"
```

#### Android Studio

Linux:

```bash
echo "-Djava.net.preferIPv6Addresses=true" >> "$(ls -dt ~/.config/Google/AndroidStudio*/ | head -1)studio.vmoptions"
```

macOS:

```bash
echo "-Djava.net.preferIPv6Addresses=true" >> "$(ls -dt ~/Library/Application\ Support/Google/AndroidStudio*/ | head -1)studio.vmoptions"
```

Windows (PowerShell):

```powershell
Add-Content (Get-ChildItem "$env:APPDATA\Google\AndroidStudio*\studio.vmoptions" | Sort-Object LastWriteTime | Select-Object -Last 1).FullName "-Djava.net.preferIPv6Addresses=true"
```

After saving the file, stop any running Gradle daemon with `./gradlew --stop` and restart the IDE so the new option is picked up.

## Command-line Gradle

If you run Gradle outside an IDE there is no vmoptions file. Set the same property through `org.gradle.jvmargs` in your `gradle.properties` instead:

```
org.gradle.jvmargs=-Djava.net.preferIPv6Addresses=true
```

Or export it globally so every Gradle invocation gets it:

```
export GRADLE_OPTS="-Djava.net.preferIPv6Addresses=true"
```

<hr>

That's it — Gradle will now prefer IPv6 when resolving and downloading dependencies. If you also need plain Java and Maven to do the same, see [Enabling IPv6 on Java and Maven](/enabling-ipv6-on-maven-java/). 😊
