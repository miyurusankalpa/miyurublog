---
title: How to Install OpenTracker on Debain 10
date: "2020-02-08T19:13Z"
description: "How to Install OpenTracker on Debain 10"
draft: false
---

In this tutorial, we will be installing open tracker with IPv6 enabled on Debian 10 buster.

First install the required packages

```bash
sudo apt install libowfat-dev make git build-essential zlib1g-dev libowfat-dev make git
```

then create a user called opentracker and switch to that user

```bash
sudo useradd opentracker -m
su - opentracker
```

clone the opentracker repo

```bash
git clone git://erdgeist.org/opentracker
```

go to opentracker directory

```bash
cd opentracker
```

Open the makefile

```bash
nano Makefile
```

In the makefile, uncomment the following

- to enable IPv6

```{diff}
-#FEATURES+=-DWANT_V6
+FEATURES+=-DWANT_V6
```

- to enable gzip compression

```{diff}
-#FEATURES+=-DWANT_COMPRESSION_GZIP
+FEATURES+=-DWANT_COMPRESSION_GZIP
```

save the file and run make.

```bash
make
```

finally run following command to start opentracker in background.

```bash
./opentracker &
```

by default the tracker will run on 6969 port on both UDP and TCP.

visit [http://serverIP:6969/stats](http://serverIP:6969/stats) to view the tracker stats.

To change default settings, copy the sample opentracker.conf file and edit as needed.

```bash
cp opentracker.conf.sample opentracker.conf
nano opentracker.conf
```

Remember to open the port in the firewall for both UDP and TCP if a firewall is in place.
