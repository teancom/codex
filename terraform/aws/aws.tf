#
# Amazonia - Terraform Configuration for
# AWS BOSH + Cloud Foundry
#
# author:  James Hunt <james@niftylogic.com>
# created: 2016-06-14
#

variable "aws_access_key" {} # Your Access Key ID     (required)
variable "aws_secret_key" {} # Your Secret Access Key (required)
variable "aws_vpc_name"   {} # Name of your VPC       (required)
variable "aws_key_name"   {} # Name of EC2 Keypair    (required)

variable "aws_region"     { default = "us-west-2" } # AWS Region
variable "network"        { default = "10.4" }      # First 2 octets of your /16

variable "aws_az1"        { default = "a" }
variable "aws_az2"        { default = "b" }
variable "aws_az3"        { default = "c" }

#
# VPC NAT AMI
#
# These are the region-specific IDs for the Amazon-suggested
# AMI for running a NAT instance inside of a VPC:
#
#    amzn-ami-vpc-nat-hvm-2014.03.2.x86_64-gp2
#
# The username to log into the nat box is `ec2-user'
#
variable "aws_nat_ami" {
  default = {
    us-east-1      = "ami-4c9e4b24"
    us-west-1      = "ami-1d2b2958"
    us-west-2      = "ami-8b6912bb"
    ap-northeast-1 = "ami-49c29e48"
    ap-northeast-2 = "ami-0199506f"
    ap-southeast-1 = "ami-d482da86"
    ap-southeast-2 = "ami-a164029b"
    eu-west-1      = "ami-5b60b02c"
    sa-east-1      = "ami-8b72db96"
  }
}

#
# Generic Ubuntu AMI
#
# These are the region-specific IDs for an
# HVM-compatible Ubuntu image:
#
#    ubuntu/images/hvm-ssd/ubuntu-xenial-16.04-amd64-server-20160610
#
# (Note: this AMI is missing from the Seoul [ap-northeast-2] region)
#
# The username to log into the bastion is `ubuntu'
#
variable "aws_ubuntu_ami" {
  default = {
    us-east-1      = "ami-f652979b"
    us-west-1      = "ami-08490c68"
    us-west-2      = "ami-d06a90b0"
    ap-northeast-1 = "ami-b601ead7"
    #ap-northeast-2 = "" # MISSING
    ap-southeast-1 = "ami-e7a67584"
    ap-southeast-2 = "ami-61e3ca02"
    eu-west-1      = "ami-0ae77879"
    sa-east-1      = "ami-09991365"
  }
}

###############################################################

provider "aws" {
  access_key = "${var.aws_access_key}"
  secret_key = "${var.aws_secret_key}"
  region     = "${var.aws_region}"
}

###############################################################

resource "aws_vpc" "default" {
  cidr_block           = "${var.network}.0.0/16"
  enable_dns_hostnames = "true"
  tags { Name = "${var.aws_vpc_name}" }
}



########   #######  ##     ## ######## #### ##    ##  ######
##     ## ##     ## ##     ##    ##     ##  ###   ## ##    ##
##     ## ##     ## ##     ##    ##     ##  ####  ## ##
########  ##     ## ##     ##    ##     ##  ## ## ## ##   ####
##   ##   ##     ## ##     ##    ##     ##  ##  #### ##    ##
##    ##  ##     ## ##     ##    ##     ##  ##   ### ##    ##
##     ##  #######   #######     ##    #### ##    ##  ######

resource "aws_internet_gateway" "default" {
  vpc_id = "${aws_vpc.default.id}"
}
resource "aws_route_table" "external" {
  vpc_id = "${aws_vpc.default.id}"
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = "${aws_internet_gateway.default.id}"
  }
  tags { Name = "${var.aws_vpc_name}-external" }
}
resource "aws_route_table" "internal" {
  vpc_id = "${aws_vpc.default.id}"
  route {
    cidr_block = "0.0.0.0/0"
    instance_id = "${aws_instance.nat.id}"
  }
  tags { Name = "${var.aws_vpc_name}-internal" }
}



 ######  ##     ## ########  ##    ## ######## ########  ######
##    ## ##     ## ##     ## ###   ## ##          ##    ##    ##
##       ##     ## ##     ## ####  ## ##          ##    ##
 ######  ##     ## ########  ## ## ## ######      ##     ######
      ## ##     ## ##     ## ##  #### ##          ##          ##
##    ## ##     ## ##     ## ##   ### ##          ##    ##    ##
 ######   #######  ########  ##    ## ########    ##     ######

###############################################################
# DMZ - De-militarized Zone for NAT box ONLY
#
resource "aws_subnet" "dmz" {
  vpc_id     = "${aws_vpc.default.id}"
  cidr_block = "${var.network}.0.0/24"
  tags { Name = "${var.aws_vpc_name}-dmz" }
}
resource "aws_route_table_association" "dmz" {
  subnet_id      = "${aws_subnet.dmz.id}"
  route_table_id = "${aws_route_table.external.id}"
}
output "aws.network.dmz.subnet" {
  value = "${aws_subnet.dmz.id}"
}

###############################################################
# GLOBAL - Global Infrastructure
#
# This includes the following:
#   - proto-BOSH
#   - SHIELD
#   - Vault (for deployment credentials)
#   - Concourse (for deployment automation)
#   - Bolo
#
resource "aws_subnet" "global-infra-1" {
  vpc_id            = "${aws_vpc.default.id}"
  cidr_block        = "${var.network}.1.0/24"
  availability_zone = "${var.aws_region}${var.aws_az1}"
  tags { Name = "${var.aws_vpc_name}-global-infra-1" }
}
resource "aws_route_table_association" "global-infra-1" {
  subnet_id      = "${aws_subnet.global-infra-1.id}"
  route_table_id = "${aws_route_table.internal.id}"
}
output "aws.network.global-infra-1.subnet" {
  value = "${aws_subnet.global-infra-1.id}"
}
resource "aws_subnet" "global-infra-2" {
  vpc_id            = "${aws_vpc.default.id}"
  cidr_block        = "${var.network}.2.0/24"
  availability_zone = "${var.aws_region}${var.aws_az2}"
  tags { Name = "${var.aws_vpc_name}-global-infra-2" }
}
resource "aws_route_table_association" "global-infra-2" {
  subnet_id      = "${aws_subnet.global-infra-2.id}"
  route_table_id = "${aws_route_table.internal.id}"
}
output "aws.network.global-infra-2.subnet" {
  value = "${aws_subnet.global-infra-2.id}"
}
resource "aws_subnet" "global-infra-3" {
  vpc_id            = "${aws_vpc.default.id}"
  cidr_block        = "${var.network}.3.0/24"
  availability_zone = "${var.aws_region}${var.aws_az3}"
  tags { Name = "${var.aws_vpc_name}-global-infra-3" }
}
resource "aws_route_table_association" "global-infra-3" {
  subnet_id      = "${aws_subnet.global-infra-3.id}"
  route_table_id = "${aws_route_table.internal.id}"
}
output "aws.network.global-infra-3.subnet" {
  value = "${aws_subnet.global-infra-3.id}"
}

resource "aws_subnet" "global-openvpn-1" {
  vpc_id            = "${aws_vpc.default.id}"
  cidr_block        = "${var.network}.4.0/25"
  availability_zone = "${var.aws_region}${var.aws_az1}"
  tags { Name = "${var.aws_vpc_name}-global-openvpn-1" }
}
resource "aws_route_table_association" "global-openvpn-1" {
  subnet_id      = "${aws_subnet.global-openvpn-1.id}"
  route_table_id = "${aws.route_table.external.id}"
}
output "aws.network.global-openvpn-1" {
  value = "${aws_subnet.global-openvpn-1.id}"
}
resource "aws_subnet" "global-openvpn-2" {
  vpc_id            = "${aws_vpc.default.id}"
  cidr_block        = "${var.network}.4.128/25"
  availability_zone = "${var.aws_region}${var.aws_az2}"
  tags { Name = "${var.aws_vpc_name}-global-openvpn-2" }
}
resource "aws_route_table_association" "global-openvpn-2" {
  subnet_id      = "${aws_subnet.global-openvpn-2.id}"
  route_table_id = "${aws.route_table.external.id}"
}
output "aws.network.global-openvpn-2" {
  value = "${aws_subnet.global-openvpn-2.id}"
}


###############################################################
# DEV-INFRA - Development Site Infrastructure
#
#  Primarily used for BOSH directors, deployed by proto-BOSH
#
#  Also reserved for situations where you prefer to have
#  dedicated, per-site infrastructure (SHIELD, Bolo, etc.)
#
#  Three zone-isolated networks are provided for HA and
#  fault-tolerance in deployments that support / require it.
#
resource "aws_subnet" "dev-infra-1" {
  vpc_id            = "${aws_vpc.default.id}"
  cidr_block        = "${var.network}.16.0/24"
  availability_zone = "${var.aws_region}${var.aws_az1}"
  tags { Name = "${var.aws_vpc_name}-dev-infra" }
}
resource "aws_route_table_association" "dev-infra-1" {
  subnet_id      = "${aws_subnet.dev-infra-1.id}"
  route_table_id = "${aws_route_table.internal.id}"
}
output "aws.network.dev-infra-1.subnet" {
  value = "${aws_subnet.dev-infra-1.id}"
}
resource "aws_subnet" "dev-infra-2" {
  vpc_id            = "${aws_vpc.default.id}"
  cidr_block        = "${var.network}.17.0/24"
  availability_zone = "${var.aws_region}${var.aws_az1}"
  tags { Name = "${var.aws_vpc_name}-dev-infra" }
}
resource "aws_route_table_association" "dev-infra-2" {
  subnet_id      = "${aws_subnet.dev-infra-2.id}"
  route_table_id = "${aws_route_table.internal.id}"
}
output "aws.network.dev-infra-2.subnet" {
  value = "${aws_subnet.dev-infra-2.id}"
}
resource "aws_subnet" "dev-infra-3" {
  vpc_id            = "${aws_vpc.default.id}"
  cidr_block        = "${var.network}.18.0/24"
  availability_zone = "${var.aws_region}${var.aws_az1}"
  tags { Name = "${var.aws_vpc_name}-dev-infra" }
}
resource "aws_route_table_association" "dev-infra-3" {
  subnet_id      = "${aws_subnet.dev-infra-3.id}"
  route_table_id = "${aws_route_table.internal.id}"
}
output "aws.network.dev-infra-3.subnet" {
  value = "${aws_subnet.dev-infra-3.id}"
}

###############################################################
# DEV-CF-EDGE - Cloud Foundry Routers
#
#  These subnets are separate from the rest of Cloud Foundry
#  to ensure that we can properly ACL the public-facing HTTP
#  routers independent of the private core / services.
#
resource "aws_subnet" "dev-cf-edge-1" {
  vpc_id            = "${aws_vpc.default.id}"
  cidr_block        = "${var.network}.19.0/25"
  availability_zone = "${var.aws_region}${var.aws_az1}"
  tags { Name = "${var.aws_vpc_name}-dev-cf-edge-1" }
}
resource "aws_route_table_association" "dev-cf-edge-1" {
  subnet_id      = "${aws_subnet.dev-cf-edge-1.id}"
  route_table_id = "${aws_route_table.external.id}"
}
output "aws.network.dev-cf-edge-1.subnet" {
  value = "${aws_subnet.dev-cf-edge-1.id}"
}
resource "aws_subnet" "dev-cf-edge-2" {
  vpc_id            = "${aws_vpc.default.id}"
  cidr_block        = "${var.network}.19.128/25"
  availability_zone = "${var.aws_region}${var.aws_az2}"
  tags { Name = "${var.aws_vpc_name}-dev-cf-edge-2" }
}
resource "aws_route_table_association" "dev-cf-edge-2" {
  subnet_id      = "${aws_subnet.dev-cf-edge-2.id}"
  route_table_id = "${aws_route_table.external.id}"
}
output "aws.network.dev-cf-edge-2.subnet" {
  value = "${aws_subnet.dev-cf-edge-2.id}"
}

###############################################################
# DEV-CF-CORE - Cloud Foundry Core
#
#  These subnets contain the private core components of Cloud
#  Foundry.  They are separate for reasons of isolation via
#  Network ACLs.
#
resource "aws_subnet" "dev-cf-core-1" {
  vpc_id            = "${aws_vpc.default.id}"
  cidr_block        = "${var.network}.20.0/24"
  availability_zone = "${var.aws_region}${var.aws_az1}"
  tags { Name = "${var.aws_vpc_name}-dev-cf-core-1" }
}
resource "aws_route_table_association" "dev-cf-core-1" {
  subnet_id      = "${aws_subnet.dev-cf-core-1.id}"
  route_table_id = "${aws_route_table.internal.id}"
}
output "aws.network.dev-cf-core-1.subnet" {
  value = "${aws_subnet.dev-cf-core-1.id}"
}
resource "aws_subnet" "dev-cf-core-2" {
  vpc_id            = "${aws_vpc.default.id}"
  cidr_block        = "${var.network}.21.0/24"
  availability_zone = "${var.aws_region}${var.aws_az2}"
  tags { Name = "${var.aws_vpc_name}-dev-cf-core-2" }
}
resource "aws_route_table_association" "dev-cf-core-2" {
  subnet_id      = "${aws_subnet.dev-cf-core-2.id}"
  route_table_id = "${aws_route_table.internal.id}"
}
output "aws.network.dev-cf-core-2.subnet" {
  value = "${aws_subnet.dev-cf-core-2.id}"
}
resource "aws_subnet" "dev-cf-core-3" {
  vpc_id            = "${aws_vpc.default.id}"
  cidr_block        = "${var.network}.22.0/24"
  availability_zone = "${var.aws_region}${var.aws_az3}"
  tags { Name = "${var.aws_vpc_name}-dev-cf-core-3" }
}
resource "aws_route_table_association" "dev-cf-core-3" {
  subnet_id      = "${aws_subnet.dev-cf-core-3.id}"
  route_table_id = "${aws_route_table.internal.id}"
}
output "aws.network.dev-cf-core-3.subnet" {
  value = "${aws_subnet.dev-cf-core-3.id}"
}

###############################################################
# DEV-CF-RUNTIME - Cloud Foundry Runtime
#
#  These subnets house the Cloud Foundry application runtime
#  (either DEA-next or Diego).
#
resource "aws_subnet" "dev-cf-runtime-1" {
  vpc_id            = "${aws_vpc.default.id}"
  cidr_block        = "${var.network}.23.0/24"
  availability_zone = "${var.aws_region}${var.aws_az1}"
  tags { Name = "${var.aws_vpc_name}-dev-cf-runtime-1" }
}
resource "aws_route_table_association" "dev-cf-runtime-1" {
  subnet_id      = "${aws_subnet.dev-cf-runtime-1.id}"
  route_table_id = "${aws_route_table.internal.id}"
}
output "aws.network.dev-cf-runtime-1.subnet" {
  value = "${aws_subnet.dev-cf-runtime-1.id}"
}
resource "aws_subnet" "dev-cf-runtime-2" {
  vpc_id            = "${aws_vpc.default.id}"
  cidr_block        = "${var.network}.24.0/24"
  availability_zone = "${var.aws_region}${var.aws_az2}"
  tags { Name = "${var.aws_vpc_name}-dev-cf-runtime-2" }
}
resource "aws_route_table_association" "dev-cf-runtime-2" {
  subnet_id      = "${aws_subnet.dev-cf-runtime-2.id}"
  route_table_id = "${aws_route_table.internal.id}"
}
output "aws.network.dev-cf-runtime-2.subnet" {
  value = "${aws_subnet.dev-cf-runtime-2.id}"
}
resource "aws_subnet" "dev-cf-runtime-3" {
  vpc_id            = "${aws_vpc.default.id}"
  cidr_block        = "${var.network}.25.0/24"
  availability_zone = "${var.aws_region}${var.aws_az3}"
  tags { Name = "${var.aws_vpc_name}-dev-cf-runtime-3" }
}
resource "aws_route_table_association" "dev-cf-runtime-3" {
  subnet_id      = "${aws_subnet.dev-cf-runtime-3.id}"
  route_table_id = "${aws_route_table.internal.id}"
}
output "aws.network.dev-cf-runtime-3.subnet" {
  value = "${aws_subnet.dev-cf-runtime-3.id}"
}

###############################################################
# DEV-CF-SVC - Cloud Foundry Services
#
#  These subnets house Service Broker deployments for
#  Cloud Foundry Marketplace services.
#
resource "aws_subnet" "dev-cf-svc-1" {
  vpc_id            = "${aws_vpc.default.id}"
  cidr_block        = "${var.network}.26.0/24"
  availability_zone = "${var.aws_region}${var.aws_az1}"
  tags { Name = "${var.aws_vpc_name}-dev-cf-svc-1" }
}
resource "aws_route_table_association" "dev-cf-svc-1" {
  subnet_id      = "${aws_subnet.dev-cf-svc-1.id}"
  route_table_id = "${aws_route_table.internal.id}"
}
output "aws.network.dev-cf-svc-1.subnet" {
  value = "${aws_subnet.dev-cf-svc-1.id}"
}
resource "aws_subnet" "dev-cf-svc-2" {
  vpc_id            = "${aws_vpc.default.id}"
  cidr_block        = "${var.network}.27.0/24"
  availability_zone = "${var.aws_region}${var.aws_az2}"
  tags { Name = "${var.aws_vpc_name}-dev-cf-svc-2" }
}
resource "aws_route_table_association" "dev-cf-svc-2" {
  subnet_id      = "${aws_subnet.dev-cf-svc-2.id}"
  route_table_id = "${aws_route_table.internal.id}"
}
output "aws.network.dev-cf-svc-2.subnet" {
  value = "${aws_subnet.dev-cf-svc-2.id}"
}
resource "aws_subnet" "dev-cf-svc-3" {
  vpc_id            = "${aws_vpc.default.id}"
  cidr_block        = "${var.network}.28.0/24"
  availability_zone = "${var.aws_region}${var.aws_az3}"
  tags { Name = "${var.aws_vpc_name}-dev-cf-svc-3" }
}
resource "aws_route_table_association" "dev-cf-svc-3" {
  subnet_id      = "${aws_subnet.dev-cf-svc-3.id}"
  route_table_id = "${aws_route_table.internal.id}"
}
output "aws.network.dev-cf-svc-3.subnet" {
  value = "${aws_subnet.dev-cf-svc-3.id}"
}

###############################################################
# STAGING-INFRA - Staging Site Infrastructure
#
#  Primarily used for BOSH directors, deployed by proto-BOSH
#
#  Also reserved for situations where you prefer to have
#  dedicated, per-site infrastructure (SHIELD, Bolo, etc.)
#
#  Three zone-isolated networks are provided for HA and
#  fault-tolerance in deployments that support / require it.
#
resource "aws_subnet" "staging-infra-1" {
  vpc_id            = "${aws_vpc.default.id}"
  cidr_block        = "${var.network}.32.0/24"
  availability_zone = "${var.aws_region}${var.aws_az1}"
  tags { Name = "${var.aws_vpc_name}-staging-infra" }
}
resource "aws_route_table_association" "staging-infra-1" {
  subnet_id      = "${aws_subnet.staging-infra-1.id}"
  route_table_id = "${aws_route_table.internal.id}"
}
output "aws.network.staging-infra-1.subnet" {
  value = "${aws_subnet.staging-infra-1.id}"
}
resource "aws_subnet" "staging-infra-2" {
  vpc_id            = "${aws_vpc.default.id}"
  cidr_block        = "${var.network}.33.0/24"
  availability_zone = "${var.aws_region}${var.aws_az1}"
  tags { Name = "${var.aws_vpc_name}-staging-infra" }
}
resource "aws_route_table_association" "staging-infra-2" {
  subnet_id      = "${aws_subnet.staging-infra-2.id}"
  route_table_id = "${aws_route_table.internal.id}"
}
output "aws.network.staging-infra-2.subnet" {
  value = "${aws_subnet.staging-infra-2.id}"
}
resource "aws_subnet" "staging-infra-3" {
  vpc_id            = "${aws_vpc.default.id}"
  cidr_block        = "${var.network}.34.0/24"
  availability_zone = "${var.aws_region}${var.aws_az1}"
  tags { Name = "${var.aws_vpc_name}-staging-infra" }
}
resource "aws_route_table_association" "staging-infra-3" {
  subnet_id      = "${aws_subnet.staging-infra-3.id}"
  route_table_id = "${aws_route_table.internal.id}"
}
output "aws.network.staging-infra-3.subnet" {
  value = "${aws_subnet.staging-infra-3.id}"
}

###############################################################
# STAGING-CF-EDGE - Cloud Foundry Routers
#
#  These subnets are separate from the rest of Cloud Foundry
#  to ensure that we can properly ACL the public-facing HTTP
#  routers independent of the private core / services.
#
resource "aws_subnet" "staging-cf-edge-1" {
  vpc_id            = "${aws_vpc.default.id}"
  cidr_block        = "${var.network}.35.0/25"
  availability_zone = "${var.aws_region}${var.aws_az1}"
  tags { Name = "${var.aws_vpc_name}-staging-cf-edge-1" }
}
resource "aws_route_table_association" "staging-cf-edge-1" {
  subnet_id      = "${aws_subnet.staging-cf-edge-1.id}"
  route_table_id = "${aws_route_table.external.id}"
}
output "aws.network.staging-cf-edge-1.subnet" {
  value = "${aws_subnet.staging-cf-edge-1.id}"
}
resource "aws_subnet" "staging-cf-edge-2" {
  vpc_id            = "${aws_vpc.default.id}"
  cidr_block        = "${var.network}.35.128/25"
  availability_zone = "${var.aws_region}${var.aws_az2}"
  tags { Name = "${var.aws_vpc_name}-staging-cf-edge-2" }
}
resource "aws_route_table_association" "staging-cf-edge-2" {
  subnet_id      = "${aws_subnet.staging-cf-edge-2.id}"
  route_table_id = "${aws_route_table.external.id}"
}
output "aws.network.staging-cf-edge-2.subnet" {
  value = "${aws_subnet.staging-cf-edge-2.id}"
}

###############################################################
# STAGING-CF-CORE - Cloud Foundry Core
#
#  These subnets contain the private core components of Cloud
#  Foundry.  They are separate for reasons of isolation via
#  Network ACLs.
#
resource "aws_subnet" "staging-cf-core-1" {
  vpc_id            = "${aws_vpc.default.id}"
  cidr_block        = "${var.network}.36.0/24"
  availability_zone = "${var.aws_region}${var.aws_az1}"
  tags { Name = "${var.aws_vpc_name}-staging-cf-core-1" }
}
resource "aws_route_table_association" "staging-cf-core-1" {
  subnet_id      = "${aws_subnet.staging-cf-core-1.id}"
  route_table_id = "${aws_route_table.internal.id}"
}
output "aws.network.staging-cf-core-1.subnet" {
  value = "${aws_subnet.staging-cf-core-1.id}"
}
resource "aws_subnet" "staging-cf-core-2" {
  vpc_id            = "${aws_vpc.default.id}"
  cidr_block        = "${var.network}.37.0/24"
  availability_zone = "${var.aws_region}${var.aws_az2}"
  tags { Name = "${var.aws_vpc_name}-staging-cf-core-2" }
}
resource "aws_route_table_association" "staging-cf-core-2" {
  subnet_id      = "${aws_subnet.staging-cf-core-2.id}"
  route_table_id = "${aws_route_table.internal.id}"
}
output "aws.network.staging-cf-core-2.subnet" {
  value = "${aws_subnet.staging-cf-core-2.id}"
}
resource "aws_subnet" "staging-cf-core-3" {
  vpc_id            = "${aws_vpc.default.id}"
  cidr_block        = "${var.network}.38.0/24"
  availability_zone = "${var.aws_region}${var.aws_az3}"
  tags { Name = "${var.aws_vpc_name}-staging-cf-core-3" }
}
resource "aws_route_table_association" "staging-cf-core-3" {
  subnet_id      = "${aws_subnet.staging-cf-core-3.id}"
  route_table_id = "${aws_route_table.internal.id}"
}
output "aws.network.staging-cf-core-3.subnet" {
  value = "${aws_subnet.staging-cf-core-3.id}"
}

###############################################################
# STAGING-CF-RUNTIME - Cloud Foundry Runtime
#
#  These subnets house the Cloud Foundry application runtime
#  (either DEA-next or Diego).
#
resource "aws_subnet" "staging-cf-runtime-1" {
  vpc_id            = "${aws_vpc.default.id}"
  cidr_block        = "${var.network}.39.0/24"
  availability_zone = "${var.aws_region}${var.aws_az1}"
  tags { Name = "${var.aws_vpc_name}-staging-cf-runtime-1" }
}
resource "aws_route_table_association" "staging-cf-runtime-1" {
  subnet_id      = "${aws_subnet.staging-cf-runtime-1.id}"
  route_table_id = "${aws_route_table.internal.id}"
}
output "aws.network.staging-cf-runtime-1.subnet" {
  value = "${aws_subnet.staging-cf-runtime-1.id}"
}
resource "aws_subnet" "staging-cf-runtime-2" {
  vpc_id            = "${aws_vpc.default.id}"
  cidr_block        = "${var.network}.40.0/24"
  availability_zone = "${var.aws_region}${var.aws_az2}"
  tags { Name = "${var.aws_vpc_name}-staging-cf-runtime-2" }
}
resource "aws_route_table_association" "staging-cf-runtime-2" {
  subnet_id      = "${aws_subnet.staging-cf-runtime-2.id}"
  route_table_id = "${aws_route_table.internal.id}"
}
output "aws.network.staging-cf-runtime-2.subnet" {
  value = "${aws_subnet.staging-cf-runtime-2.id}"
}
resource "aws_subnet" "staging-cf-runtime-3" {
  vpc_id            = "${aws_vpc.default.id}"
  cidr_block        = "${var.network}.41.0/24"
  availability_zone = "${var.aws_region}${var.aws_az3}"
  tags { Name = "${var.aws_vpc_name}-staging-cf-runtime-3" }
}
resource "aws_route_table_association" "staging-cf-runtime-3" {
  subnet_id      = "${aws_subnet.staging-cf-runtime-3.id}"
  route_table_id = "${aws_route_table.internal.id}"
}
output "aws.network.staging-cf-runtime-3.subnet" {
  value = "${aws_subnet.staging-cf-runtime-3.id}"
}

###############################################################
# STAGING-CF-SVC - Cloud Foundry Services
#
#  These subnets house Service Broker deployments for
#  Cloud Foundry Marketplace services.
#
resource "aws_subnet" "staging-cf-svc-1" {
  vpc_id            = "${aws_vpc.default.id}"
  cidr_block        = "${var.network}.42.0/24"
  availability_zone = "${var.aws_region}${var.aws_az1}"
  tags { Name = "${var.aws_vpc_name}-staging-cf-svc-1" }
}
resource "aws_route_table_association" "staging-cf-svc-1" {
  subnet_id      = "${aws_subnet.staging-cf-svc-1.id}"
  route_table_id = "${aws_route_table.internal.id}"
}
output "aws.network.staging-cf-svc-1.subnet" {
  value = "${aws_subnet.staging-cf-svc-1.id}"
}
resource "aws_subnet" "staging-cf-svc-2" {
  vpc_id            = "${aws_vpc.default.id}"
  cidr_block        = "${var.network}.43.0/24"
  availability_zone = "${var.aws_region}${var.aws_az2}"
  tags { Name = "${var.aws_vpc_name}-staging-cf-svc-2" }
}
resource "aws_route_table_association" "staging-cf-svc-2" {
  subnet_id      = "${aws_subnet.staging-cf-svc-2.id}"
  route_table_id = "${aws_route_table.internal.id}"
}
output "aws.network.staging-cf-svc-2.subnet" {
  value = "${aws_subnet.staging-cf-svc-2.id}"
}
resource "aws_subnet" "staging-cf-svc-3" {
  vpc_id            = "${aws_vpc.default.id}"
  cidr_block        = "${var.network}.44.0/24"
  availability_zone = "${var.aws_region}${var.aws_az3}"
  tags { Name = "${var.aws_vpc_name}-staging-cf-svc-3" }
}
resource "aws_route_table_association" "staging-cf-svc-3" {
  subnet_id      = "${aws_subnet.staging-cf-svc-3.id}"
  route_table_id = "${aws_route_table.internal.id}"
}
output "aws.network.staging-cf-svc-3.subnet" {
  value = "${aws_subnet.staging-cf-svc-3.id}"
}

###############################################################
# PROD-INFRA - Production Site Infrastructure
#
#  Primarily used for BOSH directors, deployed by proto-BOSH
#
#  Also reserved for situations where you prefer to have
#  dedicated, per-site infrastructure (SHIELD, Bolo, etc.)
#
#  Three zone-isolated networks are provided for HA and
#  fault-tolerance in deployments that support / require it.
#
resource "aws_subnet" "prod-infra-1" {
  vpc_id            = "${aws_vpc.default.id}"
  cidr_block        = "${var.network}.48.0/24"
  availability_zone = "${var.aws_region}${var.aws_az1}"
  tags { Name = "${var.aws_vpc_name}-prod-infra" }
}
resource "aws_route_table_association" "prod-infra-1" {
  subnet_id      = "${aws_subnet.prod-infra-1.id}"
  route_table_id = "${aws_route_table.internal.id}"
}
output "aws.network.prod-infra-1.subnet" {
  value = "${aws_subnet.prod-infra-1.id}"
}
resource "aws_subnet" "prod-infra-2" {
  vpc_id            = "${aws_vpc.default.id}"
  cidr_block        = "${var.network}.49.0/24"
  availability_zone = "${var.aws_region}${var.aws_az1}"
  tags { Name = "${var.aws_vpc_name}-prod-infra" }
}
resource "aws_route_table_association" "prod-infra-2" {
  subnet_id      = "${aws_subnet.prod-infra-2.id}"
  route_table_id = "${aws_route_table.internal.id}"
}
output "aws.network.prod-infra-2.subnet" {
  value = "${aws_subnet.prod-infra-2.id}"
}
resource "aws_subnet" "prod-infra-3" {
  vpc_id            = "${aws_vpc.default.id}"
  cidr_block        = "${var.network}.50.0/24"
  availability_zone = "${var.aws_region}${var.aws_az1}"
  tags { Name = "${var.aws_vpc_name}-prod-infra" }
}
resource "aws_route_table_association" "prod-infra-3" {
  subnet_id      = "${aws_subnet.prod-infra-3.id}"
  route_table_id = "${aws_route_table.internal.id}"
}
output "aws.network.prod-infra-3.subnet" {
  value = "${aws_subnet.prod-infra-3.id}"
}

###############################################################
# PROD-CF-EDGE - Cloud Foundry Routers
#
#  These subnets are separate from the rest of Cloud Foundry
#  to ensure that we can properly ACL the public-facing HTTP
#  routers independent of the private core / services.
#
resource "aws_subnet" "prod-cf-edge-1" {
  vpc_id            = "${aws_vpc.default.id}"
  cidr_block        = "${var.network}.51.0/25"
  availability_zone = "${var.aws_region}${var.aws_az1}"
  tags { Name = "${var.aws_vpc_name}-prod-cf-edge-1" }
}
resource "aws_route_table_association" "prod-cf-edge-1" {
  subnet_id      = "${aws_subnet.prod-cf-edge-1.id}"
  route_table_id = "${aws_route_table.external.id}"
}
output "aws.network.prod-cf-edge-1.subnet" {
  value = "${aws_subnet.prod-cf-edge-1.id}"
}
resource "aws_subnet" "prod-cf-edge-2" {
  vpc_id            = "${aws_vpc.default.id}"
  cidr_block        = "${var.network}.51.128/25"
  availability_zone = "${var.aws_region}${var.aws_az2}"
  tags { Name = "${var.aws_vpc_name}-prod-cf-edge-2" }
}
resource "aws_route_table_association" "prod-cf-edge-2" {
  subnet_id      = "${aws_subnet.prod-cf-edge-2.id}"
  route_table_id = "${aws_route_table.external.id}"
}
output "aws.network.prod-cf-edge-2.subnet" {
  value = "${aws_subnet.prod-cf-edge-2.id}"
}

###############################################################
# PROD-CF-CORE - Cloud Foundry Core
#
#  These subnets contain the private core components of Cloud
#  Foundry.  They are separate for reasons of isolation via
#  Network ACLs.
#
resource "aws_subnet" "prod-cf-core-1" {
  vpc_id            = "${aws_vpc.default.id}"
  cidr_block        = "${var.network}.52.0/24"
  availability_zone = "${var.aws_region}${var.aws_az1}"
  tags { Name = "${var.aws_vpc_name}-prod-cf-core-1" }
}
resource "aws_route_table_association" "prod-cf-core-1" {
  subnet_id      = "${aws_subnet.prod-cf-core-1.id}"
  route_table_id = "${aws_route_table.internal.id}"
}
output "aws.network.prod-cf-core-1.subnet" {
  value = "${aws_subnet.prod-cf-core-1.id}"
}
resource "aws_subnet" "prod-cf-core-2" {
  vpc_id            = "${aws_vpc.default.id}"
  cidr_block        = "${var.network}.53.0/24"
  availability_zone = "${var.aws_region}${var.aws_az2}"
  tags { Name = "${var.aws_vpc_name}-prod-cf-core-2" }
}
resource "aws_route_table_association" "prod-cf-core-2" {
  subnet_id      = "${aws_subnet.prod-cf-core-2.id}"
  route_table_id = "${aws_route_table.internal.id}"
}
output "aws.network.prod-cf-core-2.subnet" {
  value = "${aws_subnet.prod-cf-core-2.id}"
}
resource "aws_subnet" "prod-cf-core-3" {
  vpc_id            = "${aws_vpc.default.id}"
  cidr_block        = "${var.network}.54.0/24"
  availability_zone = "${var.aws_region}${var.aws_az3}"
  tags { Name = "${var.aws_vpc_name}-prod-cf-core-3" }
}
resource "aws_route_table_association" "prod-cf-core-3" {
  subnet_id      = "${aws_subnet.prod-cf-core-3.id}"
  route_table_id = "${aws_route_table.internal.id}"
}
output "aws.network.prod-cf-core-3.subnet" {
  value = "${aws_subnet.prod-cf-core-3.id}"
}

###############################################################
# PROD-CF-RUNTIME - Cloud Foundry Runtime
#
#  These subnets house the Cloud Foundry application runtime
#  (either DEA-next or Diego).
#
resource "aws_subnet" "prod-cf-runtime-1" {
  vpc_id            = "${aws_vpc.default.id}"
  cidr_block        = "${var.network}.55.0/24"
  availability_zone = "${var.aws_region}${var.aws_az1}"
  tags { Name = "${var.aws_vpc_name}-prod-cf-runtime-1" }
}
resource "aws_route_table_association" "prod-cf-runtime-1" {
  subnet_id      = "${aws_subnet.prod-cf-runtime-1.id}"
  route_table_id = "${aws_route_table.internal.id}"
}
output "aws.network.prod-cf-runtime-1.subnet" {
  value = "${aws_subnet.prod-cf-runtime-1.id}"
}
resource "aws_subnet" "prod-cf-runtime-2" {
  vpc_id            = "${aws_vpc.default.id}"
  cidr_block        = "${var.network}.56.0/24"
  availability_zone = "${var.aws_region}${var.aws_az2}"
  tags { Name = "${var.aws_vpc_name}-prod-cf-runtime-2" }
}
resource "aws_route_table_association" "prod-cf-runtime-2" {
  subnet_id      = "${aws_subnet.prod-cf-runtime-2.id}"
  route_table_id = "${aws_route_table.internal.id}"
}
output "aws.network.prod-cf-runtime-2.subnet" {
  value = "${aws_subnet.prod-cf-runtime-2.id}"
}
resource "aws_subnet" "prod-cf-runtime-3" {
  vpc_id            = "${aws_vpc.default.id}"
  cidr_block        = "${var.network}.57.0/24"
  availability_zone = "${var.aws_region}${var.aws_az3}"
  tags { Name = "${var.aws_vpc_name}-prod-cf-runtime-3" }
}
resource "aws_route_table_association" "prod-cf-runtime-3" {
  subnet_id      = "${aws_subnet.prod-cf-runtime-3.id}"
  route_table_id = "${aws_route_table.internal.id}"
}
output "aws.network.prod-cf-runtime-3.subnet" {
  value = "${aws_subnet.prod-cf-runtime-3.id}"
}

###############################################################
# PROD-CF-SVC - Cloud Foundry Services
#
#  These subnets house Service Broker deployments for
#  Cloud Foundry Marketplace services.
#
resource "aws_subnet" "prod-cf-svc-1" {
  vpc_id            = "${aws_vpc.default.id}"
  cidr_block        = "${var.network}.58.0/24"
  availability_zone = "${var.aws_region}${var.aws_az1}"
  tags { Name = "${var.aws_vpc_name}-prod-cf-svc-1" }
}
resource "aws_route_table_association" "prod-cf-svc-1" {
  subnet_id      = "${aws_subnet.prod-cf-svc-1.id}"
  route_table_id = "${aws_route_table.internal.id}"
}
output "aws.network.prod-cf-svc-1.subnet" {
  value = "${aws_subnet.prod-cf-svc-1.id}"
}
resource "aws_subnet" "prod-cf-svc-2" {
  vpc_id            = "${aws_vpc.default.id}"
  cidr_block        = "${var.network}.59.0/24"
  availability_zone = "${var.aws_region}${var.aws_az2}"
  tags { Name = "${var.aws_vpc_name}-prod-cf-svc-2" }
}
resource "aws_route_table_association" "prod-cf-svc-2" {
  subnet_id      = "${aws_subnet.prod-cf-svc-2.id}"
  route_table_id = "${aws_route_table.internal.id}"
}
output "aws.network.prod-cf-svc-2.subnet" {
  value = "${aws_subnet.prod-cf-svc-2.id}"
}
resource "aws_subnet" "prod-cf-svc-3" {
  vpc_id            = "${aws_vpc.default.id}"
  cidr_block        = "${var.network}.60.0/24"
  availability_zone = "${var.aws_region}${var.aws_az3}"
  tags { Name = "${var.aws_vpc_name}-prod-cf-svc-3" }
}
resource "aws_route_table_association" "prod-cf-svc-3" {
  subnet_id      = "${aws_subnet.prod-cf-svc-3.id}"
  route_table_id = "${aws_route_table.internal.id}"
}
output "aws.network.prod-cf-svc-3.subnet" {
  value = "${aws_subnet.prod-cf-svc-3.id}"
}



##    ##    ###     ######  ##        ######
###   ##   ## ##   ##    ## ##       ##    ##
####  ##  ##   ##  ##       ##       ##
## ## ## ##     ## ##       ##        ######
##  #### ######### ##       ##             ##
##   ### ##     ## ##    ## ##       ##    ##
##    ## ##     ##  ######  ########  ######

resource "aws_network_acl" "hardened" {
  vpc_id = "${aws_vpc.default.id}"
  subnet_ids = [
    "${aws_subnet.dev-infra-1.id}",
    "${aws_subnet.dev-infra-2.id}",
    "${aws_subnet.dev-infra-3.id}",
    "${aws_subnet.dev-cf-edge-1.id}",
    "${aws_subnet.dev-cf-edge-2.id}",
    "${aws_subnet.dev-cf-core-1.id}",
    "${aws_subnet.dev-cf-core-2.id}",
    "${aws_subnet.dev-cf-core-3.id}",
    "${aws_subnet.dev-cf-runtime-1.id}",
    "${aws_subnet.dev-cf-runtime-2.id}",
    "${aws_subnet.dev-cf-runtime-3.id}",
    "${aws_subnet.dev-cf-svc-1.id}",
    "${aws_subnet.dev-cf-svc-2.id}",
    "${aws_subnet.dev-cf-svc-3.id}",

    "${aws_subnet.staging-infra-1.id}",
    "${aws_subnet.staging-infra-2.id}",
    "${aws_subnet.staging-infra-3.id}",
    "${aws_subnet.staging-cf-edge-1.id}",
    "${aws_subnet.staging-cf-edge-2.id}",
    "${aws_subnet.staging-cf-core-1.id}",
    "${aws_subnet.staging-cf-core-2.id}",
    "${aws_subnet.staging-cf-core-3.id}",
    "${aws_subnet.staging-cf-runtime-1.id}",
    "${aws_subnet.staging-cf-runtime-2.id}",
    "${aws_subnet.staging-cf-runtime-3.id}",
    "${aws_subnet.staging-cf-svc-1.id}",
    "${aws_subnet.staging-cf-svc-2.id}",
    "${aws_subnet.staging-cf-svc-3.id}",

    "${aws_subnet.prod-infra-1.id}",
    "${aws_subnet.prod-infra-2.id}",
    "${aws_subnet.prod-infra-3.id}",
    "${aws_subnet.prod-cf-edge-1.id}",
    "${aws_subnet.prod-cf-edge-2.id}",
    "${aws_subnet.prod-cf-core-1.id}",
    "${aws_subnet.prod-cf-core-2.id}",
    "${aws_subnet.prod-cf-core-3.id}",
    "${aws_subnet.prod-cf-runtime-1.id}",
    "${aws_subnet.prod-cf-runtime-2.id}",
    "${aws_subnet.prod-cf-runtime-3.id}",
    "${aws_subnet.prod-cf-svc-1.id}",
    "${aws_subnet.prod-cf-svc-2.id}",
    "${aws_subnet.prod-cf-svc-3.id}"
  ]
  tags { Name = "${var.aws_vpc_name}-hardened" }



  #### ##    ##  ######   ########  ########  ######   ######
   ##  ###   ## ##    ##  ##     ## ##       ##    ## ##    ##
   ##  ####  ## ##        ##     ## ##       ##       ##
   ##  ## ## ## ##   #### ########  ######    ######   ######
   ##  ##  #### ##    ##  ##   ##   ##             ##       ##
   ##  ##   ### ##    ##  ##    ##  ##       ##    ## ##    ##
  #### ##    ##  ######   ##     ## ########  ######   ######

  # Allow ICMP Echo Reply packets (type 0)
  # (response to ping/tracepath)
  ingress {
    rule_no    = "1"
    protocol   = "icmp"
    icmp_type  = "0"
    icmp_code  = "-1"
    to_port = "0"
    from_port = "0"
    cidr_block = "0.0.0.0/0"
    action     = "allow"
  }
  # Allow ICMP Destination Unreachable (type 3) packets
  # (host/net unreachables, port closed, fragmentation
  #  issues, etc.)
  ingress {
    rule_no    = "2"
    protocol   = "icmp"
    icmp_type  = "3"
    icmp_code  = "-1"

    to_port = "0"
    from_port = "0"
    cidr_block = "0.0.0.0/0"
    action     = "allow"
  }
  # Allow ICMP Echo packets (type 8)
  # (ping/tracepath initiator)
  ingress {
    rule_no    = "3"
    protocol   = "icmp"
    icmp_type  = "8"
    icmp_code  = "-1"
    to_port = "0"
    from_port = "0"
    cidr_block = "0.0.0.0/0"
    action     = "allow"
  }
  # Allow ICMP Time Exceeded (type 11)
  # (tracepath TTL issue)
  ingress {
    rule_no    = "4"
    protocol   = "icmp"
    icmp_type  = "11"
    icmp_code  = "-1"
    to_port = "0"
    from_port = "0"
    cidr_block = "0.0.0.0/0"
    action     = "allow"
  }

  # Allow SSH traffic from the Bastion Host (in the DMZ)
  ingress {
    rule_no    = "101"
    protocol   = "tcp"
    from_port  = "22"
    to_port    = "22"
    cidr_block = "${aws_instance.bastion.private_ip}/32"
    action     = "allow"
  }

  # OTHER RULES NEEDED:
  #  - BOSH (for proto-BOSH to deploy BOSH directors)
  #  - SHIELD (for backups to/from infranet)
  #  - Bolo (to submit monitoring egress to infranet)
  #  - Concourse (either direct acccess to BOSH, or worker communication)
  #  - Vault (jumpboxen need to get to Vault for creds.  also, concourse workers)

  # All other traffic is blocked by an implicit
  # Block all other traffic.



  ########  ######   ########  ########  ######   ######
  ##       ##    ##  ##     ## ##       ##    ## ##    ##
  ##       ##        ##     ## ##       ##       ##
  ######   ##   #### ########  ######    ######   ######
  ##       ##    ##  ##   ##   ##             ##       ##
  ##       ##    ##  ##    ##  ##       ##    ## ##    ##
  ########  ######   ##     ## ########  ######   ######

  # Allow ICMP Echo Reply packets (type 0)
  # (response to ping/tracepath)
  egress {
    rule_no    = "1"
    protocol   = "icmp"
    icmp_type  = "0"
    icmp_code  = "-1"
    to_port    = "0"
    from_port  = "0"
    cidr_block = "0.0.0.0/0"
    action     = "allow"
  }
  # Allow ICMP Destination Unreachable (type 3) packets
  # (host/net unreachables, port closed, fragmentation
  #  issues, etc.)
  egress {
    rule_no    = "2"
    protocol   = "icmp"
    icmp_type  = "3"
    icmp_code  = "-1"
    to_port = "0"
    from_port = "0"
    cidr_block = "0.0.0.0/0"
    action     = "allow"
  }
  # Allow ICMP Echo packets (type 8)
  # (ping/tracepath initiator)
  egress {
    rule_no    = "3"
    protocol   = "icmp"
    icmp_type  = "8"
    icmp_code  = "-1"
    to_port = "0"
    from_port = "0"
    cidr_block = "0.0.0.0/0"
    action     = "allow"
  }
  # Allow ICMP Time Exceeded (type 11)
  # (tracepath TTL issue)
  egress {
    rule_no    = "4"
    protocol   = "icmp"
    icmp_type  = "11"
    icmp_code  = "-1"
    to_port = "0"
    from_port = "0"
    cidr_block = "0.0.0.0/0"
    action     = "allow"
  }
  # Allow return traffic on ephemeral ports.
  # (Linux kernels use 32768-61000 for ephemeral ports)
  egress {
    rule_no    = "101"
    protocol   = "tcp"
    from_port  = "32768"
    to_port    = "65535"
    cidr_block = "0.0.0.0/0" # FIXME: lockdown to prod / bastion
    action     = "allow"
  }
  egress {
    rule_no    = "102"
    protocol   = "udp"
    from_port  = "32768"
    to_port    = "65535"
    cidr_block = "0.0.0.0/0" # FIXME: lockdown to prod / bastion
    action     = "allow"
  }

  # All other traffic is blocked by an implicit
  # DENY rule in the Network ACL (inside of AWS)
}



 ######  ########  ######          ######   ########   #######  ##     ## ########   ######
##    ## ##       ##    ##        ##    ##  ##     ## ##     ## ##     ## ##     ## ##    ##
##       ##       ##              ##        ##     ## ##     ## ##     ## ##     ## ##
 ######  ######   ##              ##   #### ########  ##     ## ##     ## ########   ######
      ## ##       ##              ##    ##  ##   ##   ##     ## ##     ## ##              ##
##    ## ##       ##    ## ###    ##    ##  ##    ##  ##     ## ##     ## ##        ##    ##
 ######  ########  ######  ###     ######   ##     ##  #######   #######  ##         ######

resource "aws_security_group" "dmz" {
  name        = "dmz"
  description = "Allow services from the private subnet through NAT"
  vpc_id      = "${aws_vpc.default.id}"
  tags { Name = "${var.aws_vpc_name}-dmz" }

  # ICMP traffic control
  ingress {
    from_port   = -1
    to_port     = -1
    protocol    = "icmp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  # Allow SSH traffic into the NAT box
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  # Allow all traffic through the NAT from inside the VPC
  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["${var.network}.0.0/16"]
  }


  # ICMP traffic control (outbound)
  # Allows diagnostic utilities like ping / traceroute
  # to function as expected, and aid in troubleshooting.
  egress {
    from_port   = -1
    to_port     = -1
    protocol    = "icmp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Allow *ALL* outbound TCP traffic.
  # (security ppl may not like this...)
  egress {
    from_port = 0
    to_port   = 65535
    protocol  = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Allow *ALL* outbound UDP traffic.
  # (security ppl may not like this...)
  egress {
    from_port = 0
    to_port   = 65535
    protocol  = "udp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
resource "aws_security_group" "wide-open" {
  name        = "wide-open"
  description = "Allow everything in and out"
  vpc_id      = "${aws_vpc.default.id}"
  tags { Name = "${var.aws_vpc_name}-wide-open" }

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}



##    ##    ###    ########
###   ##   ## ##      ##
####  ##  ##   ##     ##
## ## ## ##     ##    ##
##  #### #########    ##
##   ### ##     ##    ##
##    ## ##     ##    ##

resource "aws_instance" "nat" {
  ami             = "${lookup(var.aws_nat_ami, var.aws_region)}"
  instance_type   = "t2.small"
  key_name        = "${var.aws_key_name}"
  vpc_security_group_ids = ["${aws_security_group.dmz.id}"]
  subnet_id       = "${aws_subnet.dmz.id}"

  associate_public_ip_address = true
  source_dest_check           = false

  tags { Name = "nat" }
}
resource "aws_eip" "nat" {
  instance = "${aws_instance.nat.id}"
  vpc      = true
}
output "box.nat.public" {
  value = "${aws_eip.nat.public_ip}"
}



########     ###     ######  ######## ####  #######  ##    ##
##     ##   ## ##   ##    ##    ##     ##  ##     ## ###   ##
##     ##  ##   ##  ##          ##     ##  ##     ## ####  ##
########  ##     ##  ######     ##     ##  ##     ## ## ## ##
##     ## #########       ##    ##     ##  ##     ## ##  ####
##     ## ##     ## ##    ##    ##     ##  ##     ## ##   ###
########  ##     ##  ######     ##    ####  #######  ##    ##

resource "aws_instance" "bastion" {
  ami             = "${lookup(var.aws_ubuntu_ami, var.aws_region)}"
  instance_type   = "t2.small"
  key_name        = "${var.aws_key_name}"
  vpc_security_group_ids = ["${aws_security_group.dmz.id}"]
  subnet_id       = "${aws_subnet.dmz.id}"

  tags { Name = "bastion" }
}
resource "aws_eip" "bastion" {
  instance = "${aws_instance.bastion.id}"
  vpc      = true
}
output "box.bastion.public" {
  value = "${aws_eip.bastion.public_ip}"
}
