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

ipcalc 10.0.0.0/20
Address:   10.0.0.0             00001010.00000000.0000 0000.00000000
Netmask:   255.255.240.0 = 20   11111111.11111111.1111 0000.00000000
Wildcard:  0.0.15.255           00000000.00000000.0000 1111.11111111
=>
Network:   10.0.0.0/20          00001010.00000000.0000 0000.00000000
HostMin:   10.0.0.1             00001010.00000000.0000 0000.00000001
HostMax:   10.0.15.254          00001010.00000000.0000 1111.11111110
Broadcast: 10.0.15.255          00001010.00000000.0000 1111.11111111
Hosts/Net: 4094                  Class A, Private Internet

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
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.19"

  name = "platform"
  cidr = "10.0.0.0/16"

  azs = local.selected_azs
  # See ipcalc 10.0.0.0/16 /20
  private_subnets = ["10.0.0.0/20", "10.0.16.0/20", "10.0.32.0/20"]
  # See ipcalc 10.0.0.0/16 /24
  public_subnets = ["10.0.50.0/24", "10.0.51.0/24", "10.0.52.0/24"]
  intra_subnets  = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]


  enable_nat_gateway     = true
  single_nat_gateway     = true
  one_nat_gateway_per_az = false

  private_subnet_tags = {
    # Tags subnets for Karpenter auto-discovery.
    "karpenter.sh/discovery" = local.cluster_name
  }
}
