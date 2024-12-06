locals {
  region_azs = {
    "us-east-2" = ["us-east-2a", "us-east-2b", "us-east-2c"]
    "us-east-1" = ["us-east-1a", "us-east-1b", "us-east-1c"]
  }

  selected_azs = lookup(local.region_azs, data.aws_region.current.name, [])
}

/* 
https://github.com/terraform-aws-modules/terraform-aws-vpc

ipcalc 10.0.0.0/16

Address:   10.0.0.0             00001010.00000000. 00000000.00000000
Netmask:   255.255.0.0 = 16     11111111.11111111. 00000000.00000000
Wildcard:  0.0.255.255          00000000.00000000. 11111111.11111111
=>
Network:   10.0.0.0/16          00001010.00000000. 00000000.00000000
HostMin:   10.0.0.1             00001010.00000000. 00000000.00000001
HostMax:   10.0.255.254         00001010.00000000. 11111111.11111110
Broadcast: 10.0.255.255         00001010.00000000. 11111111.11111111
Hosts/Net: 65534                 Class A, Private Internet


ipcalc 10.0.1.0/24   

Address:   10.0.1.0             00001010.00000000.00000001. 00000000
Netmask:   255.255.255.0 = 24   11111111.11111111.11111111. 00000000
Wildcard:  0.0.0.255            00000000.00000000.00000000. 11111111
=>
Network:   10.0.1.0/24          00001010.00000000.00000001. 00000000
HostMin:   10.0.1.1             00001010.00000000.00000001. 00000001
HostMax:   10.0.1.254           00001010.00000000.00000001. 11111110
Broadcast: 10.0.1.255           00001010.00000000.00000001. 11111111
Hosts/Net: 254                   Class A, Private Internet */
module "vpc" {
  source = "terraform-aws-modules/vpc/aws"

  name = "platform"
  cidr = "10.0.0.0/16"

  azs             = local.selected_azs
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  public_subnets  = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]


  enable_nat_gateway     = true
  single_nat_gateway     = true
  one_nat_gateway_per_az = false
}