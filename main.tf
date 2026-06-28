module "autoscaling" {
  source = "github.com/prashantmj13/sfg-autoscaling?ref=v1.0.0"

  project_id  = var.project_id
  region      = var.region
  network     = var.network
  subnetwork  = var.subnetwork
  name_prefix = var.name_prefix
  sfg_port    = var.ps_port

  min_replicas           = var.min_replicas
  max_replicas           = var.max_replicas
  cpu_utilization_target = var.cpu_utilization_target

  startup_script = templatefile("${path.module}/startup_script.sh.tpl", {
    gcs_bucket         = var.gcs_bucket
    gcs_installer_path = var.gcs_installer_path
    ps_install_dir     = var.ps_install_dir
    ps_port            = var.ps_port
    sfg_engine_ip      = var.sfg_engine_ip
    sfg_engine_port    = var.sfg_engine_port
  })

  labels = var.labels
}

module "load_balancer" {
  source = "github.com/prashantmj13/sfg-load-balancer?ref=v1.0.0"

  project_id         = var.project_id
  region             = var.region
  network            = var.network
  subnetwork         = var.subnetwork
  instance_group_url = module.autoscaling.instance_group_url
  ports              = concat([var.ps_port], var.additional_lb_ports)
  name_prefix        = var.name_prefix

  labels = var.labels
}
