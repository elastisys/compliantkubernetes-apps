prefix = "pipeline-wc"
zone   = "ch-gva-2"

inventory_file = "/github/workspace/apps/pipeline/config/exoscale/pipeline-wc-config/inventory.ini"

ssh_public_keys = [
  # Put your public SSH key here
  "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQDSIsQRjkyCFVLvAXnF3S9boopS/W621BABBXNc58P0rz5yN8bDJrnYjcb6o8xQ+SFJOB/Gv1NjI8CAdJ3902wD4a7rldEhCCw7c4tHb8eMjxdHYKc6poh/oaZWvj6PX24K5NbjtPdrvfa0ak0M1Cg9WCePiEW+IETN0nIEoQFIfTkwDi8Fzk0XW+d2T7AM6Wti41cKmUhmn44VxXk2Mq2spRYyrjPrXj5qXd+Q8+WnNXgjadNs8P6MEjx8zqxgQNb2y+ZzVFHwtwslLU51/Jfpe8MW+eQFGfh870TlKFP+aXcrOMayMA0CpHRo/gj6i3Phe2X3zaDAUF5e1DN/rp+fhA+9rvJ+XIglpOJi+q1Tb25c4cwekV0TItiLJjfsI2RNOC/a7AI3iaUaY9SVSrHlA2UMO3ZXaJ2qrxSHJnfpfd4DIXG9GyBbZANYso09/SAHXR40ZjG75B2Uz4dQLKru940LA/EYklzU9Pvi30WxJmYPu/Au09UiXoaXqpeEgGk= haorui.peng@elastisys.com"
]

machines = {
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
  },
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

nodeport_whitelist = [
  "0.0.0.0/0"
]

ssh_whitelist = [
  "0.0.0.0/0"
]

api_server_whitelist = [
  "0.0.0.0/0"
]
