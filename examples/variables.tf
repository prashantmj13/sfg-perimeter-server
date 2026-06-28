variable "project_id" {
  type = string
}

variable "host_project_id" {
  type = string
}

variable "region" {
  type    = string
  default = "us-central1"
}

variable "gcs_bucket" {
  type        = string
  description = "GCS bucket containing the perimeter server installer."
}

variable "sfg_engine_ip" {
  type        = string
  description = "Private IP of the SFG engine in the internal network."
}


