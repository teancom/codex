
variable "network"        { default = "10.4" }      # First 2 octets of your /16

variable "tenant_name"    { default = "codex"}
variable "user_name"      { default = "admin"}
variable "password"       { default = "supersecret"}
variable "auth_url"       { default = ""}
variable "key_pair"       { default = "codex"}


provider "openstack" {
    user_name  = "${var.user_name}"
    tenant_name = "${var.tenant_name}"
    password  = "${var.password}"
    auth_url  = "${var.auth_url}"
}

######################################
#         Security Groups
#####################################

resource "openstack_networking_secgroup_v2" "dmz" {
  name = "dmz"
  description = "Allow services from the private subnet through NAT"
}

resource "openstack_networking_secgroup_rule_v2" "icmp_traffic_ingress" {
  direction = "ingress"
  ethertype = "IPv4"
  protocol = "icmp"                    # Required if specifying port range
  region = "RegionOne"
  remote_ip_prefix = "0.0.0.0/0"
  security_group_id = "${openstack_networking_secgroup_v2.dmz.id}"
}

resource "openstack_networking_secgroup_rule_v2" "nat_ssh_ingress" {
  direction = "ingress"
  ethertype = "IPv4"
  protocol = "tcp"                    # Required if specifying port range
  port_range_min = 22
  port_range_max = 22
  region = "RegionOne"
  remote_ip_prefix = "0.0.0.0/0"
  security_group_id = "${openstack_networking_secgroup_v2.dmz.id}"
}

resource "openstack_networking_secgroup_rule_v2" "vpc_tcp_ingress" {
  direction = "ingress"
  ethertype = "IPv4"
  protocol = "tcp"                    # Required if specifying port range
  port_range_min = 1
  port_range_max = 65535
  region = "RegionOne"
  remote_ip_prefix = "${var.network}.0.0/0"
  security_group_id = "${openstack_networking_secgroup_v2.dmz.id}"
}

resource "openstack_networking_secgroup_rule_v2" "vpc_udp_ingress" {
  direction = "ingress"
  ethertype = "IPv4"
  protocol = "udp"                    # Required if specifying port range
  port_range_min = 1
  port_range_max = 65535
  region = "RegionOne"
  remote_ip_prefix = "${var.network}.0.0/0"
  security_group_id = "${openstack_networking_secgroup_v2.dmz.id}"
}

resource "openstack_networking_secgroup_rule_v2" "tcp_egress" {
  direction = "egress"
  ethertype = "IPv4"
  protocol = "tcp"                    # Required if specifying port range
  port_range_min = 1
  port_range_max = 65535
  region = "RegionOne"
  remote_ip_prefix = "0.0.0.0/0"
  security_group_id = "${openstack_networking_secgroup_v2.dmz.id}"
}

resource "openstack_networking_secgroup_rule_v2" "udp_egress" {
  direction = "egress"
  ethertype = "IPv4"
  protocol = "udp"                    # Required if specifying port range
  port_range_min = 1
  port_range_max = 65535
  region = "RegionOne"
  remote_ip_prefix = "0.0.0.0/0"
  security_group_id = "${openstack_networking_secgroup_v2.dmz.id}"
}

resource "openstack_networking_secgroup_v2" "wide-open" {
  name = "wide-open"
  description = "Allow everything in and out"
}

resource "openstack_networking_secgroup_rule_v2" "wide-open_ingress" {
  direction = "ingress"
  ethertype = "IPv4"
  protocol = "icmp"                   # Required if specifying port range
  region = "RegionOne"
  remote_ip_prefix = "0.0.0.0/0"
  security_group_id = "${openstack_networking_secgroup_v2.wide-open.id}"
}

resource "openstack_networking_secgroup_v2" "cf-db" {
  name = "cf-db"
  description = "Allow access to the MySQL port"
}

resource "openstack_networking_secgroup_rule_v2" "cf-db_ingress" {
  direction = "ingress"
  ethertype = "IPv4"
  protocol = "tcp"                    # Required if specifying port range
  port_range_min = 3306
  port_range_max = 3306
  region = "RegionOne"
  remote_ip_prefix = "0.0.0.0/0"
  security_group_id = "${openstack_networking_secgroup_v2.cf-db.id}"
}

resource "openstack_networking_secgroup_v2" "openvpn" {
  name = "openvpn"
  description = "Allow HTTPS in and out"
}

resource "openstack_networking_secgroup_rule_v2" "openvpn_ingress" {
  direction = "ingress"
  ethertype = "IPv4"
  protocol = "tcp"                    # Required if specifying port range
  port_range_min = 443
  port_range_max = 443
  region = "RegionOne"
  remote_ip_prefix = "0.0.0.0/0"
  security_group_id = "${openstack_networking_secgroup_v2.openvpn.id}"
}

################################
#          Networks
###############################

#FIXME: Finish these

resource "openstack_networking_network_v2" "internal" {
  name = "internal"  
}

resource "openstack_networking_network_v2" "external" {
  name = "external"  
}

###############################
#           Subnets
###############################

resource "openstack_networking_subnet_v2" "dmz" {
  name = "dmz"
  network_id = "${openstack_networking_network_v2.external.id}"
  cidr = "${var.network}.0.0/24"
}

output "openstack_networking_network_v2.external.dmz.subnet" {
  value = "${openstack_networking_subnet_v2.dmz.id}"
}

######### Global ############

resource "openstack_networking_subnet_v2" "global-infra-0" {
  network_id = "${openstack_networking_network_v2.internal.id}"
  cidr = "${var.network}.1.0/24"
}

output "openstack_networking_network_v2.external.global-infra-0.subnet" {
  value = "${openstack_networking_subnet_v2.global-infra-0.id}"
}

resource "openstack_networking_subnet_v2" "global-infra-1" {
  network_id = "${openstack_networking_network_v2.internal.id}"
  cidr = "${var.network}.2.0/24"
}

output "openstack_networking_network_v2.external.global-infra-1.subnet" {
  value = "${openstack_networking_subnet_v2.global-infra-1.id}"
}

resource "openstack_networking_subnet_v2" "global-infra-2" {
  network_id = "${openstack_networking_network_v2.internal.id}"
  cidr = "${var.network}.3.0/24"
}

output "openstack_networking_network_v2.external.global-infra-2.subnet" {
  value = "${openstack_networking_subnet_v2.global-infra-2.id}"
}

resource "openstack_networking_subnet_v2" "global-openvpn-0" {
  network_id = "${openstack_networking_network_v2.external.id}"
  cidr = "${var.network}.4.0/25"
}

output "openstack_networking_network_v2.external.global-openvpn-0.subnet" {
  value = "${openstack_networking_subnet_v2.global-openvpn-0.id}"
}

resource "openstack_networking_subnet_v2" "global-openvpn-1" {
  network_id = "${openstack_networking_network_v2.external.id}"
  cidr = "${var.network}.4.128/25"
}

output "openstack_networking_network_v2.external.global-openvpn-1.subnet" {
  value = "${openstack_networking_subnet_v2.global-openvpn-1.id}"
}

######## Development ##########


resource "openstack_networking_subnet_v2" "dev-infra-0" {
  network_id = "${openstack_networking_network_v2.internal.id}"
  cidr = "${var.network}.16.0/24"
}

output "openstack_networking_network_v2.external.dev-infra-0.subnet" {
  value = "${openstack_networking_subnet_v2.dev-infra-0.id}"
}

resource "openstack_networking_subnet_v2" "dev-infra-1" {
  network_id = "${openstack_networking_network_v2.internal.id}"
  cidr = "${var.network}.17.0/24"
}

output "openstack_networking_network_v2.external.dev-infra-1.subnet" {
  value = "${openstack_networking_subnet_v2.dev-infra-1.id}"
}

resource "openstack_networking_subnet_v2" "dev-infra-2" {
  network_id = "${openstack_networking_network_v2.internal.id}"
  cidr = "${var.network}.18.0/24"
}

output "openstack_networking_network_v2.external.dev-infra-2.subnet" {
  value = "${openstack_networking_subnet_v2.dev-infra-2.id}"
}


######## DEV-CF-EDGE ##########

resource "openstack_networking_subnet_v2" "dev-cf-edge-0" {
  network_id = "${openstack_networking_network_v2.external.id}"
  cidr = "${var.network}.19.0/25"
}

output "openstack_networking_network_v2.external.dev-cf-edge-0.subnet" {
  value = "${openstack_networking_subnet_v2.dev-cf-edge-0.id}"
}

resource "openstack_networking_subnet_v2" "dev-cf-edge-1" {
  network_id = "${openstack_networking_network_v2.external.id}"
  cidr = "${var.network}.19.128/25"
}

output "openstack_networking_network_v2.external.dev-cf-edge-1.subnet" {
  value = "${openstack_networking_subnet_v2.dev-cf-edge-1.id}"
}

######## DEC-CF-CORE #########

resource "openstack_networking_subnet_v2" "dev-cf-core-0" {
  network_id = "${openstack_networking_network_v2.internal.id}"
  cidr = "${var.network}.20.0/24"
}

output "openstack_networking_network_v2.external.dev-cf-core-0.subnet" {
  value = "${openstack_networking_subnet_v2.dev-cf-core-0.id}"
}

resource "openstack_networking_subnet_v2" "dev-cf-core-1" {
  network_id = "${openstack_networking_network_v2.internal.id}"
  cidr = "${var.network}.21.0/24"
}

output "openstack_networking_network_v2.external.dev-cf-core-1.subnet" {
  value = "${openstack_networking_subnet_v2.dev-cf-core-1.id}"
}

resource "openstack_networking_subnet_v2" "dev-cf-core-2" {
  network_id = "${openstack_networking_network_v2.internal.id}"
  cidr = "${var.network}.22.0/24"
}

output "openstack_networking_network_v2.external.dev-cf-core-2.subnet" {
  value = "${openstack_networking_subnet_v2.dev-cf-core-2.id}"
}


######## DEC-CF-CORE #########

resource "openstack_networking_subnet_v2" "dev-cf-runtime-0" {
  network_id = "${openstack_networking_network_v2.internal.id}"
  cidr = "${var.network}.23.0/24"
}

output "openstack_networking_network_v2.external.dev-cf-runtime-0.subnet" {
  value = "${openstack_networking_subnet_v2.dev-cf-runtime-0.id}"
}


resource "openstack_networking_subnet_v2" "dev-cf-runtime-1" {
  network_id = "${openstack_networking_network_v2.internal.id}"
  cidr = "${var.network}.24.0/24"
}

output "openstack_networking_network_v2.external.dev-cf-runtime-1.subnet" {
  value = "${openstack_networking_subnet_v2.dev-cf-runtime-1.id}"
}

resource "openstack_networking_subnet_v2" "dev-cf-runtime-2" {
  network_id = "${openstack_networking_network_v2.internal.id}"
  cidr = "${var.network}.25.0/24"
}

output "openstack_networking_network_v2.external.dev-cf-runtime-2.subnet" {
  value = "${openstack_networking_subnet_v2.dev-cf-runtime-2.id}"
}



###############################
#      Volumes and Instances
###############################

resource "openstack_blockstorage_volume_v2" "volume_bastion" {
  region = "RegionOne"
  name = "volume_bastion"
  description = "bastion Volume"
  size = 2
}


resource "openstack_compute_instance_v2" "bastion" {
  name = "bastion"
  image_name = "cirros-0.3.4-x86_64-uec"
  flavor_id = "3"
  key_pair = "${var.key_pair}"
  security_groups = ["default"]

  network {
    name = "my_network"
  }

  volume {
    volume_id = "${openstack_blockstorage_volume_v2.volume_bastion.id}"
  }
}
