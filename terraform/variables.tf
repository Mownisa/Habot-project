variable "project_id" {
  description = "GCP project ID (replace with your actual project)"
  type        = string
  default     = "your-gcp-project-id"
}

variable "region" {
  description = "Primary GCP region for resources"
  type        = string
  default     = "us-central1"
}

variable "raw_landing_bucket_name" {
  description = "Name for the D0 Raw Landing GCS bucket. Must be globally unique."
  type        = string
  default     = "d0-raw-landing-habot"
}

variable "staged_dataset_id" {
  description = "BigQuery dataset ID for D1 Staged/Enforced data"
  type        = string
  default     = "d1_staged_enforced"
}

variable "pipeline_service_account_email" {
  description = "Service account used by the CI/CD pipeline to write to raw landing and read staged data"
  type        = string
  default     = "pipeline-sa@your-gcp-project-id.iam.gserviceaccount.com"
}

variable "analytics_service_account_email" {
  description = "Service account/group restricted by row-level security to only see rows scoped to their region/tenant"
  type        = string
  default     = "analytics-readers@your-gcp-project-id.iam.gserviceaccount.com"
}
