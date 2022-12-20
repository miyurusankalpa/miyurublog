---
title: AWS 1GB AMI
date: "2021-01-01T23:11Z"
description: "How to create AWS AMI with 1GB Root Volume"
draft: false
---

Linux AMIs from AWS are typically are 8GB in size. This leaves around 80% disk space unused if there are not much software is installed and if the data is another volume. 

There are some advantages creating a smaller root volume.
* Lower cost. GP3 volumes are cheaper now, but it saves money if there are lot of instances.
* Faster AMI creation.
* You can always increase size of the root volume when needed, but decreasing the size is not possible.

To do this I tried several methods.
* Simply rysnc another snapshot does not work. how ever this can work for non root volume with data.
* dd copy or manually creating the file system and copying the files failed with file system error on boot.
* Creating a raw image manually.

Unfortunately it is not easy to do, only way I found that worked was creating image using fai. Even then, there are configurations that needs to be created.

Fortunately the debian team uses fai to create the aws images and shares the code they use to create them on their git repo. https://salsa.debian.org/zmarano-guest/debian-cloud-images/-/tree/master

First setup a instance with debian buster AMI, make sure to use x64 one.

Or use the following terraform script to create the setup that I used. It will create a t3a.nano spot instance with a empty 1GB volume.

```json
provider "aws" {
  region = "eu-central-1" #change the region
  profile = "" #add your profile name
}

resource "aws_spot_instance_request" "fai_server" {
  ami                    = data.aws_ami.debian_buser.id
  instance_type          = "t3a.nano"
  spot_price             = "0.0016" #check the price when you run
  availability_zone      = data.aws_availability_zones.available.names[1]
  key_name               = "" #add your key name
  spot_type              = "one-time"
  wait_for_fulfillment   = true
}

resource "aws_ebs_volume" "ami_volume" {
  availability_zone = aws_spot_instance_request.fai_server.availability_zone
  size              = 1
  type              = "gp3"
  
  tags = {
    Name = "1gb-ami"
  }
}

resource "aws_volume_attachment" "ebs_attach_ami_vol" {
  device_name = "/dev/xvdf"
  volume_id   = aws_ebs_volume.ami_volume.id
  instance_id = aws_spot_instance_request.fai_server.spot_instance_id
}

data "aws_ami" "debian_buster" {
  most_recent = true
  owners      = ["136693071363"]

  filter {
    name   = "name"
    values = ["debian-10-amd64-*-*"]
  }
}

data "aws_availability_zones" "available" {
  state = "available"
}
```

First update the apt cache
```bash
sudo apt update
```

Install fai server and the required tools

```bash
sudo apt install fai-server fai-setup-storage dosfstools
```

Get the config space configuration the debian team is using

```bash
wget https://salsa.debian.org/zmarano-guest/debian-cloud-images/-/archive/master/debian-cloud-images-master.tar.gz?path=config_space -O debian-cloud-images-master.tar.gz
```

unzip the tar file

```bash
tar -xzf debian-cloud-images-master.tar.gz
```

In the debain teams configuration, there are some files that we don't need. We need to remove them or the process will fail.

remove the following files

```bash
rm debian-cloud-images-master-config_space/config_space/hooks/tests.CLOUD
rm debian-cloud-images-master-config_space/config_space/scripts/LAST/30-manifest
rm debian-cloud-images-master-config_space/config_space/scripts/LAST/40-info
```

Then run the following command to create the the image.

```bash
sudo /usr/sbin/fai-diskimage --verbose --hostname debian --class DEBIAN,CLOUD,TYPE_DEV,BUSTER,EC2,IPV6_DHCP,AMD64,GRUB_CLOUD_AMD64,LINUX_IMAGE_CLOUD,LAST --size 1G --cspace /home/admin/debian-cloud-images-master-config_space/config_space image_buster_ec2_amd64.raw
```

To find more info about the above command see https://salsa.debian.org/zmarano-guest/debian-cloud-images/-/blob/master/doc/details.md

if successful you will get a .raw file and a notice that it was successfully created

Now dd copy the raw file to the empty volume.

```bash
sudo dd if=image_buster_ec2_amd64.raw of=/dev/nvme1n1 bs=512k
```

check the file system of the volume

```bash
sudo partx --show /dev/nvme1n1
```

Now create a snapshot and register a AMI from the 1GB volume. 
Launch a instance from the AMI and see if it works.

Update 2022: you can also use alpinelinux AMI image which is also 1GB in size.  https://alpinelinux.org/cloud/
