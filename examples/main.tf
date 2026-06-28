provider "google" {
  project = var.project_id
  region  = var.region
}

module "sfg_perimeter" {
  source = "github.com/prashantmj13/sfg-perimeter-server?ref=v1.0.0"

  project_id  = var.project_id
  region      = var.region
  network    = "projects/${var.host_project_id}/global/networks/shared-vpc"
  subnetwork = "projects/${var.host_project_id}/regions/${var.region}/subnetworks/dmz-subnet"

  gcs_bucket         = var.gcs_bucket
  gcs_installer_path = "sfg-ps/perimeter-server-6.2.zip"

  sfg_engine_ip   = var.sfg_engine_ip
  sfg_engine_port = 5001

  min_replicas = 2
  max_replicas = 6

  labels = {
    env  = "production"
    team = "platform"
  }
}

output "perimeter_server_endpoint" {
  value = module.sfg_perimeter.lb_ip
}
