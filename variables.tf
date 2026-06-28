variable "project_id" {
  type        = string
  description = "GCP project ID."
}

variable "region" {
  type        = string
  description = "GCP region (e.g. us-central1)."
}

variable "name_prefix" {
  type        = string
  description = "Short identifier prepended to every resource name."
  default     = "sfg-ps"
}

variable "network" {
  type        = string
  description = "Self-link or URL of the VPC network."
}

variable "subnetwork" {
  type        = string
  description = "Self-link or URL of the subnetwork."
}

# ── Autoscaling ────────────────────────────────────────────────────────────────

variable "min_replicas" {
  type        = number
  description = "Minimum number of perimeter server instances."
  default     = 2
}

variable "max_replicas" {
  type        = number
  description = "Maximum number of perimeter server instances."
  default     = 6
}

variable "cpu_utilization_target" {
  type        = number
  description = "Target CPU utilization (0.0–1.0) for autoscaling."
  default     = 0.60
}

# ── Perimeter Server ──────────────────────────────────────────────────────────

variable "gcs_bucket" {
  type        = string
  description = "GCS bucket containing the IBM Sterling Perimeter Server installer."
}

variable "gcs_installer_path" {
  type        = string
  description = "Object path within gcs_bucket for the perimeter server installer ZIP (e.g. sfg-ps/ps-6.2.zip)."
}

variable "ps_install_dir" {
  type        = string
  description = "Absolute path on the VM where the perimeter server will be installed."
  default     = "/opt/sfg-perimeter"
}

variable "ps_port" {
  type        = number
  description = "Port the perimeter server listens on (used for health check and named port)."
  default     = 5001
}

variable "sfg_engine_ip" {
  type        = string
  description = "Private IP of the SFG engine (B2B Integrator) that the perimeter server connects back to."
}

variable "sfg_engine_port" {
  type        = number
  description = "Port on the SFG engine the perimeter server communicates with."
  default     = 5001
}

# ── Labels ────────────────────────────────────────────────────────────────────

variable "labels" {
  type        = map(string)
  description = "Labels applied to all resources."
  default     = {}
}
