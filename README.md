# sfg-perimeter-server

Terraform module for deploying the IBM Sterling B2B Connect Perimeter Server on GCP. Acts as a wrapper around the `sfg-autoscaling` and `sfg-load-balancer` modules — callers only need to provide perimeter server-specific inputs.

## How It Works

```
                    ┌──────────────────────────────────────────┐
                    │           sfg-perimeter-server            │
                    │                                          │
  caller ──────────►│  sfg-autoscaling (MIG + autoscaler)      │
                    │         +                                │──► lb_ip (internal TCP VIP)
                    │  sfg-load-balancer (internal TCP LB)     │
                    └──────────────────────────────────────────┘
                                      │
                              ps_port (TCP)
                                      │ startup script connects back to:
                              sfg_engine_ip:sfg_engine_port
                                      ▼
                          SFG Engine (B2B Integrator)
```

On each instance boot the startup script:
1. Installs Java 11 JDK
2. Downloads the IBM Sterling Perimeter Server installer from GCS
3. Runs silent install to `ps_install_dir`
4. Writes `perimeter_server.properties` with the instance's own IP, listen port, and SFG engine address
5. Starts the perimeter server as a systemd service (`sfg-perimeter.service`)

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

  sfg_engine_ip   = "10.0.1.50"
  sfg_engine_port = 5001
  ps_port         = 5001

  min_replicas = 2
  max_replicas = 6
}

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
| subnetwork | Subnetwork self-link | string | — | yes |
| gcs_bucket | GCS bucket containing the IBM Sterling Perimeter Server installer | string | — | yes |
| gcs_installer_path | Object path to the perimeter server installer ZIP | string | — | yes |
| sfg_engine_ip | Private IP of the SFG engine the perimeter server connects back to | string | — | yes |
| name_prefix | Resource name prefix | string | `"sfg-ps"` | no |
| min_replicas | Minimum perimeter server instance count | number | `2` | no |
| max_replicas | Maximum perimeter server instance count | number | `6` | no |
| cpu_utilization_target | Autoscaler CPU target (0.0–1.0) | number | `0.60` | no |
| ps_port | TCP port the perimeter server listens on | number | `5001` | no |
| sfg_engine_port | Port on the SFG engine the perimeter server connects to | number | `5001` | no |
| ps_install_dir | Install path on VM | string | `"/opt/sfg-perimeter"` | no |
| labels | Resource labels | map(string) | `{}` | no |

## Outputs

| Name | Description |
|---|---|
| lb_ip | Internal TCP load balancer IP — the entry point for perimeter server traffic |
| instance_group_url | MIG instance group URL |
| service_account_email | VM service account email |

## Child Modules

This module calls:

- [`sfg-autoscaling`](https://github.com/prashantmj13/sfg-autoscaling) — provisions the MIG, autoscaler, health check, firewall rules, and service account. The perimeter server startup script is injected via the `startup_script` variable.
- [`sfg-load-balancer`](https://github.com/prashantmj13/sfg-load-balancer) — provisions an internal TCP load balancer wired to the MIG via `instance_group_url`.

Security controls (no public IP, OS Login, Shielded VM, no serial port, block project SSH keys) are enforced inside `sfg-autoscaling` and apply automatically.

## Startup Script Logs

| File | Contents |
|---|---|
| `/var/log/sfg-ps-startup.log` | Startup script progress and errors |
| `/var/log/sfg-ps-install.log` | Perimeter server installer output |

## Versioning

```hcl
source = "github.com/prashantmj13/sfg-perimeter-server?ref=v1.0.0"
```
