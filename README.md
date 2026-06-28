# sfg-perimeter-server

Terraform module for deploying the IBM Sterling B2B Connect Perimeter Server on GCP. Provisions an autoscaled group of perimeter server instances fronted by an **internal TCP load balancer**.

## Architecture

```
  ┌─────────────────────────────────────────────────────────┐
  │                On-Prem / Corporate Network               │
  │                                                         │
  │  ┌──────────────────────┐   ┌────────────────────────┐  │
  │  │  SFG Application     │   │  3rd Party Apps        │  │
  │  │  Server (B2B Engine) │   │  (drop / collect files)│  │
  │  └──────────┬───────────┘   └───────────┬────────────┘  │
  │             │ port 10011 (ps_port)       │ port 8089     │
  └─────────────┼───────────────────────────┼───────────────┘
                │        Cloud VPN / Interconnect
                │                           │
                ▼                           ▼
  ┌─────────────────────────────────────────────────────────┐
  │                        GCP VPC                          │
  │                                                         │
  │  ┌───────────────────────────────────────────────────┐  │
  │  │           Internal TCP Load Balancer              │  │
  │  │   lb_ip : 10011  (SFG engine control port)       │  │
  │  │   lb_ip : 8089   (file transfer port)            │  │
  │  └────────────────────────┬──────────────────────────┘  │
  │                           │                             │
  │                           ▼                             │
  │  ┌───────────────────────────────────────────────────┐  │
  │  │          Perimeter Server MIG                     │  │
  │  │     (autoscaled across all zones in region)       │  │
  │  │                                                   │  │
  │  │   Instance 1      Instance 2      Instance N      │  │
  │  └───────────────────────────────────────────────────┘  │
  └─────────────────────────────────────────────────────────┘
```

## Port Responsibilities

| Port | Who connects | Configured by |
|---|---|---|
| `ps_port` (e.g. `10011`) | On-prem SFG Application Server — initiates control connection to perimeter server | Startup script (`localPort` in perimeter server config) |
| `additional_lb_ports` (e.g. `8089`) | 3rd party apps dropping/collecting files via VPN/Interconnect | Application team after deployment |

Both ports share the **same `lb_ip`** — one internal IP, multiple forwarding ports on the load balancer.

## Do I Need a Second Load Balancer?

**No.** Since both the SFG engine and 3rd party apps connect from your internal/corporate network via Cloud VPN or Cloud Interconnect, a single internal TCP load balancer handles all ports. Set `additional_lb_ports = [8089]` and the LB will forward both `10011` and `8089` to the same backend instances.

## What Gets Created

### Load Balancer (via sfg-load-balancer module)
- **Internal TCP Load Balancer** with a single `lb_ip` in the chosen subnet
- Forwards all ports in `[ps_port] + additional_lb_ports` to the backend
- TCP health check on `ps_port` to detect and remove unhealthy instances

### Autoscaling (via sfg-autoscaling module)
- Regional MIG spread across all zones in the region
- CPU-based autoscaler (`min_replicas` → `max_replicas`)
- Instance template with all security controls applied
- Dedicated non-default service account
- Auto-healing health check and firewall rules

### Startup Script (runs on every instance at boot)
1. Installs Java 11 JDK
2. Downloads the IBM Sterling Perimeter Server installer from GCS
3. Runs silent install to `ps_install_dir`
4. Writes `perimeter_server.properties` with `localPort = ps_port` and the SFG engine address
5. Starts the perimeter server as a systemd service (`sfg-perimeter.service`)

> The startup script configures **only `ps_port`** (the SFG engine control port). Additional file transfer ports (e.g. `8089`) are configured in the perimeter server by the application team after deployment.

## Usage

```hcl
module "sfg_perimeter" {
  source = "github.com/prashantmj13/sfg-perimeter-server?ref=v1.0.0"

  project_id  = "my-project"
  region      = "us-central1"
  network     = "projects/host/global/networks/shared-vpc"
  subnetwork  = "projects/host/regions/us-central1/subnetworks/dmz-subnet"

  gcs_bucket         = "sfg-installers"
  gcs_installer_path = "sfg-ps/perimeter-server-6.2.zip"

  # On-prem SFG Application Server connects to the perimeter server on this port
  sfg_engine_ip = "10.0.1.50"   # on-prem SFG engine IP (reachable via VPN/Interconnect)
  ps_port       = 10011

  # Additional ports opened on the LB for 3rd party apps (configured by app team post-deploy)
  additional_lb_ports = [8089]

  min_replicas = 2
  max_replicas = 6
}

# Configure your on-prem SFG Application Server to connect to:
#   Host: module.sfg_perimeter.lb_ip
#   Port: 10011 (ps_port)
#
# Configure 3rd party apps to connect to:
#   Host: module.sfg_perimeter.lb_ip
#   Port: 8089
output "perimeter_server_endpoint" {
  value = module.sfg_perimeter.lb_ip
}
```

## Requirements

| Name | Version |
|---|---|
| terraform | >= 1.5.0 |
| google provider | >= 5.0.0, < 6.0.0 |

## Inputs

| Name | Description | Type | Default | Required |
|---|---|---|---|---|
| project_id | GCP project ID | string | — | yes |
| region | GCP region | string | — | yes |
| network | VPC network self-link | string | — | yes |
| subnetwork | Subnetwork self-link — the internal LB IP is assigned from this subnet | string | — | yes |
| gcs_bucket | GCS bucket containing the perimeter server installer | string | — | yes |
| gcs_installer_path | Object path to the perimeter server installer ZIP | string | — | yes |
| sfg_engine_ip | Private IP of the on-prem SFG engine (reachable from GCP via VPN/Interconnect) | string | — | yes |
| name_prefix | Resource name prefix | string | `"sfg-ps"` | no |
| ps_port | Control port the perimeter server listens on for the SFG engine connection. Configured in startup script | number | `10011` | no |
| additional_lb_ports | Extra ports to open on the internal LB (e.g. `[8089]` for 3rd party file transfer). Not configured by startup script — app team sets these up post-deploy | list(number) | `[]` | no |
| sfg_engine_port | Port on the SFG engine the perimeter server connects back to | number | `5001` | no |
| min_replicas | Minimum perimeter server instance count | number | `2` | no |
| max_replicas | Maximum perimeter server instance count | number | `6` | no |
| cpu_utilization_target | Autoscaler CPU target (0.0–1.0) | number | `0.60` | no |
| ps_install_dir | Install path on VM | string | `"/opt/sfg-perimeter"` | no |
| labels | Resource labels applied to all resources | map(string) | `{}` | no |

## Outputs

| Name | Description |
|---|---|
| lb_ip | **Internal TCP LB IP** — single IP for all ports. SFG engine uses `lb_ip:ps_port`, 3rd party apps use `lb_ip:<additional_lb_ports>` |
| instance_group_url | MIG instance group URL |
| service_account_email | VM service account email |

## Security Controls

All controls enforced by the `sfg-autoscaling` child module:

| Control | Implementation |
|---|---|
| Instances not using default service account | Dedicated SA created; default compute SA not used |
| Block project-wide SSH keys | `metadata.block-project-ssh-keys = TRUE` |
| OS Login enabled | `metadata.enable-oslogin = TRUE` |
| Serial port disabled | `metadata.serial-port-enable = FALSE` |
| No public IP | No `access_config {}` in `network_interface` |
| Shielded VM | Secure Boot + vTPM + Integrity Monitoring enabled by default |

## Logs

| File | Contents |
|---|---|
| `/var/log/sfg-ps-startup.log` | Startup script progress and errors |
| `/var/log/sfg-ps-install.log` | Perimeter server installer output |

## Versioning

```hcl
source = "github.com/prashantmj13/sfg-perimeter-server?ref=v1.0.0"
```
