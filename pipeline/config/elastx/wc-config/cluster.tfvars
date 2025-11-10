# your Kubernetes cluster name here
cluster_name = "pipeline-elastx-wc"

# SSH key to use for access to nodes
public_key_path = "/github/workspace/apps/pipeline/config/elastx/id_rsa.pub"

# image to use for bastion, masters, standalone etcd instances, and nodes
# you can find the available images with `openstack image list`
# image = "ubuntu-24.04-server-latest"
image_uuid = "3a341474-6c80-42df-aafb-bb591fc9d96a"

# user on the node (ex. core on Container Linux, ubuntu on Ubuntu, etc.)
ssh_user = "ubuntu"

# 0|1 bastion nodes
number_of_bastions = 0

# standalone etcds
number_of_etcd = 0

# control plane availability zones
az_list = [
  "sto1",
  "sto2",
  "sto3"
]

# masters
number_of_k8s_masters = 0

number_of_k8s_masters_no_etcd = 0

number_of_k8s_masters_no_floating_ip = 0

number_of_k8s_masters_no_floating_ip_no_etcd = 0

# Flavor depends on your openstack installation
# you can get available flavor IDs through `openstack flavor list`
k8s_masters = {
  "control-plane-1" = {
    "az"          = "sto1"
    "flavor"      = "4e4318bb-8cd9-4274-8150-4eaeb478b8e5" #2C-4GB-60GB
    "floating_ip" = true
    "etcd" = true
  },
  "control-plane-2" = {
    "az"          = "sto2"
    "flavor"      = "4e4318bb-8cd9-4274-8150-4eaeb478b8e5" #2C-4GB-60GB
    "floating_ip" = true
    "etcd" = true
  },
  "control-plane-3" = {
    "az"          = "sto3"
    "flavor"      = "4e4318bb-8cd9-4274-8150-4eaeb478b8e5" #2C-4GB-60GB
    "floating_ip" = true
    "etcd" = true
  }
}

# nodes
number_of_k8s_nodes = 0

number_of_k8s_nodes_no_floating_ip = 0

# you can get available volume types through `openstack volume type list`

k8s_nodes = {
  "elastisys-0" = {
    "az"          = "sto1"
    "flavor"      = "4e4318bb-8cd9-4274-8150-4eaeb478b8e5" #2C-8GB-80GB
    "floating_ip" = true
  },
  "elastisys-1" = {
    "az"          = "sto2"
    "flavor"      = "4e4318bb-8cd9-4274-8150-4eaeb478b8e5" #2C-8GB-80GB
    "floating_ip" = true
  },
  "worker-0" = {
    "az"          = "sto1"
    "flavor"      = "4e4318bb-8cd9-4274-8150-4eaeb478b8e5" #2C-8GB-80GB
    "floating_ip" = true
  },
  "worker-1" = {
    "az"          = "sto2"
    "flavor"      = "4e4318bb-8cd9-4274-8150-4eaeb478b8e5" #2C-8GB-80GB
    "floating_ip" = true
  },
  "worker-2" = {
    "az"          = "sto3"
    "flavor"      = "4e4318bb-8cd9-4274-8150-4eaeb478b8e5" #2C-8GB-80GB
    "floating_ip" = true
  }
}

group_vars_path="/github/workspace/apps/pipeline/config/elastx/wc-config/group_vars"

# networking
# ssh access to nodes
k8s_allowed_remote_ips = ["0.0.0.0/0"]

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

router_id = "640d6657-06a9-4b71-af19-d6b8e737960f"

# use `openstack network list` to list the available external networks
network_name = "pipeline-elastx-wc"
use_existing_network = false
port_security_enabled = true
force_null_port_security = false

# UUID of the external network that will be routed to
external_net = "600b8501-78cb-4155-9c9f-23dfcba88828"
floatingip_pool = "elx-public1"


# If 1, nodes with floating IPs will transmit internal cluster traffic via floating IPs; if 0 private IPs will be used instead. Default value is 1.
use_access_ip = 0

subnet_cidr = "172.16.101.0/24"
# Or any name servers that is preferred.
dns_nameservers = [
  "1.1.1.1",
  "1.0.0.1"
]

master_server_group_policy = "anti-affinity"
node_server_group_policy = "soft-anti-affinity"
etcd_server_group_policy = ""
