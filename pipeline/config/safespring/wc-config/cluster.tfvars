# your Kubernetes cluster name here
cluster_name = "pipeline-safespring-wc"

public_key_path = "/github/workspace/apps/pipeline/config/safespring/id_rsa.pub"

# image = "ubuntu-24.04"
image_uuid = "5b126f71-3bf5-4e36-b190-fc6d9715963d"

ssh_user = "ubuntu"

number_of_bastions = 0
number_of_etcd = 0

# masters
number_of_k8s_masters = 0
number_of_k8s_masters_no_etcd = 0
number_of_k8s_masters_no_floating_ip = 0
number_of_k8s_masters_no_floating_ip_no_etcd = 0

# Flavor depends on your openstack installation
# you can get available flavor IDs through `openstack flavor list`
k8s_masters = {
  "control-plane-1" = {
    "az"          = "nova"
    "flavor"      = "0551eaa7-fa02-4e18-b69d-2999d52b6029" #2C-4GB-100GB l2.c2r4.100
    "floating_ip" = false
    "etcd"        = true
  },
  "control-plane-2" = {
    "az"          = "nova"
    "flavor"      = "0551eaa7-fa02-4e18-b69d-2999d52b6029" #2C-4GB-100GB l2.c2r4.100
    "floating_ip" = false
    "etcd"        = true
  },
  "control-plane-3" = {
    "az"          = "nova"
    "flavor"      = "0551eaa7-fa02-4e18-b69d-2999d52b6029" #2C-4GB-100GB l2.c2r4.100
    "floating_ip" = false
    "etcd"        = true
  }
}

# nodes
number_of_k8s_nodes = 0
number_of_k8s_nodes_no_floating_ip = 0

node_root_volume_size_in_gb = 50
node_volume_type = "fast"

k8s_nodes = {
  "elastisys-0" = {
    "az"                              = "nova"
    "flavor"                          = "c776ffb2-66bc-4671-8ce4-b3ab0a6795ba" #2C-4GB b2.c2r4
    "floating_ip"                     = false
    "netplan_critical_dhcp_interface" = "ens3"
    "server_group"                    = "elastisys-group"
  },
  "elastisys-1" = {
    "az"                              = "nova"
    "flavor"                          = "c776ffb2-66bc-4671-8ce4-b3ab0a6795ba" #2C-4GB b2.c2r4
    "floating_ip"                     = false
    "netplan_critical_dhcp_interface" = "ens3"
    "server_group"                    = "elastisys-group"
  },
  "worker-0" = {
    "az"                              = "nova"
    "flavor"                          = "3e072efc-8313-4652-8da5-78e6bf4c6322" #2C-8GB b2.c2r8
    "floating_ip"                     = false
    "netplan_critical_dhcp_interface" = "ens3"
    "server_group"                    = "worker-group-1"
  },
  "worker-1" = {
    "az"                              = "nova"
    "flavor"                          = "3e072efc-8313-4652-8da5-78e6bf4c6322" #2C-8GB b2.c2r8
    "floating_ip"                     = false
    "netplan_critical_dhcp_interface" = "ens3"
    "server_group"                    = "worker-group-1"
  },
  "worker-2" = {
    "az"                              = "nova"
    "flavor"                          = "3e072efc-8313-4652-8da5-78e6bf4c6322" #2C-8GB b2.c2r8
    "floating_ip"                     = false
    "netplan_critical_dhcp_interface" = "ens3"
    "server_group"                    = "worker-group-1"
  }
}

# networking
use_neutron = 0

# ssh access to nodes
k8s_allowed_remote_ips = ["194.103.95.251/32", "185.189.28.150/32", "185.189.28.233/32"]

# List of CIDR blocks allowed to initiate an API connection
master_allowed_remote_ips = ["0.0.0.0/0"]

worker_allowed_ports = [
  { # Node ports
    "protocol"         = "tcp"
    "port_range_min"   = 30000
    "port_range_max"   = 32767
    "remote_ip_prefix" = "0.0.0.0/0"
  },
  { # HTTP
    "protocol"         = "tcp"
    "port_range_min"   = 80
    "port_range_max"   = 80
    "remote_ip_prefix" = "0.0.0.0/0"
  },
  { # HTTPS
    "protocol"         = "tcp"
    "port_range_min"   = 443
    "port_range_max"   = 443
    "remote_ip_prefix" = "0.0.0.0/0"
  }
]

network_name = "public"
use_existing_network = true
port_security_enabled = true
force_null_port_security = true

external_net = "b19680b3-c00e-40f0-ad77-4448e81ae226"

use_access_ip = 1

master_server_group_policy = "anti-affinity"
node_server_group_policy = ""
etcd_server_group_policy = ""

additional_server_groups = {
  "elastisys-group" = {"policy" = "anti-affinity"},
  "worker-group-1"  = {"policy" = "anti-affinity"}
  # "worker-group-2"    = {"policy" = "anti-affinity"}
  # "redis-group-1"     = {"policy" = "anti-affinity"}
  # "rabbitmq-group-1"  = {"policy" = "anti-affinity"}
  # "postgres-group-1"  = {"policy" = "anti-affinity"}
  # ...
}
