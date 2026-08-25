terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }
  required_version = ">= 1.5.0"
}

provider "google" {
  project = var.project_id
  region  = var.region
}

# ---------------------------------------------------------------------------
# TASK 1a — D0 Raw Landing bucket
# Purpose: receives unvalidated raw payloads (e.g. student onboarding JSON)
# before they are cleaned and promoted into D1 Staged/Enforced.
# ---------------------------------------------------------------------------
resource "google_storage_bucket" "raw_landing" {
  name                        = var.raw_landing_bucket_name
  location                    = var.region
  project                     = var.project_id
  force_destroy               = false
  uniform_bucket_level_access = true # required for clean IAM-only access control
  public_access_prevention    = "enforced"

  versioning {
    enabled = true # protects against accidental overwrite of raw payloads
  }

  # Raw landing is transient by design — data should be validated and
  # promoted to D1 within days, not stored indefinitely.
  lifecycle_rule {
    condition {
      age = 30
    }
    action {
      type = "Delete"
    }
  }

  encryption {
    default_kms_key_name = null # swap in a CMEK key resource for production use
  }
}

# Only the pipeline service account may write objects into raw landing.
# Scoped with a resource-name condition so it can only touch this bucket,
# not any other bucket the SA might later be granted access to.
resource "google_storage_bucket_iam_member" "raw_landing_writer" {
  bucket = google_storage_bucket.raw_landing.name
  role   = "roles/storage.objectCreator"
  member = "serviceAccount:${var.pipeline_service_account_email}"

  condition {
    title       = "pipeline-sa-write-only"
    description = "Pipeline SA may only create objects in the raw landing bucket"
    expression  = "resource.name.startsWith(\"projects/_/buckets/${var.raw_landing_bucket_name}\")"
  }
}

# ---------------------------------------------------------------------------
# TASK 1b — D1 Staged/Enforced BigQuery dataset
# Purpose: holds validated, schema-enforced data promoted from raw landing.
# ---------------------------------------------------------------------------
resource "google_bigquery_dataset" "staged_enforced" {
  dataset_id                 = var.staged_dataset_id
  project                    = var.project_id
  location                   = var.region
  description                = "D1 Staged/Enforced: schema-validated data promoted from D0 Raw Landing"
  delete_contents_on_destroy = false

  # No default broad access — every principal below is explicit (least privilege).
  access {
    role          = "OWNER"
    user_by_email = var.pipeline_service_account_email
  }
}

# Analytics readers get table-level read access; row-level security (below)
# further restricts *which rows* they can see.
resource "google_bigquery_dataset_iam_member" "analytics_reader" {
  dataset_id = google_bigquery_dataset.staged_enforced.dataset_id
  project    = var.project_id
  role       = "roles/bigquery.dataViewer"
  member     = "serviceAccount:${var.analytics_service_account_email}"
}

resource "google_bigquery_dataset_iam_member" "pipeline_editor" {
  dataset_id = google_bigquery_dataset.staged_enforced.dataset_id
  project    = var.project_id
  role       = "roles/bigquery.dataEditor"
  member     = "serviceAccount:${var.pipeline_service_account_email}"
}

# The enforced table that raw payloads get promoted into after passing
# schema validation (see Task 3's DRF serializer for the equivalent check).
resource "google_bigquery_table" "student_onboarding" {
  dataset_id          = google_bigquery_dataset.staged_enforced.dataset_id
  table_id            = "student_onboarding"
  project             = var.project_id
  deletion_protection = true

  schema = jsonencode([
    { name = "record_id", type = "STRING", mode = "REQUIRED" },
    { name = "region", type = "STRING", mode = "REQUIRED" }, # RLS filters on this
    { name = "student_name", type = "STRING", mode = "REQUIRED" },
    { name = "guardian_email", type = "STRING", mode = "REQUIRED" },
    { name = "learning_difficulty_flag", type = "BOOLEAN", mode = "REQUIRED" },
    { name = "ingested_at", type = "TIMESTAMP", mode = "REQUIRED" },
  ])
}

# ---------------------------------------------------------------------------
# TASK 1c — Row-Level Security (RLS)
# BigQuery has no built-in "current user's region" function, so RLS is
# implemented with a small mapping table (which principal is allowed which
# region) and SESSION_USER() — a real BigQuery function that returns the
# calling principal's email — is joined against it at query time.
# ---------------------------------------------------------------------------
resource "google_bigquery_table" "region_access_map" {
  dataset_id          = google_bigquery_dataset.staged_enforced.dataset_id
  table_id            = "region_access_map"
  project             = var.project_id
  deletion_protection = false

  schema = jsonencode([
    { name = "user_email", type = "STRING", mode = "REQUIRED" },
    { name = "region", type = "STRING", mode = "REQUIRED" },
  ])
}

# RLS is applied via CREATE ROW ACCESS POLICY DDL. Terraform has no
# first-class resource for this, so it's executed as a BigQuery DDL job —
# this keeps the policy version-controlled and applied on every `apply`.
resource "google_bigquery_job" "row_access_policy" {
  job_id   = "apply-rls-student-onboarding-${formatdate("YYYYMMDDhhmmss", timestamp())}"
  project  = var.project_id
  location = var.region

  query {
    query = <<-SQL
      CREATE OR REPLACE ROW ACCESS POLICY analytics_region_scope
      ON `${var.project_id}.${var.staged_dataset_id}.student_onboarding`
      GRANT TO ("serviceAccount:${var.analytics_service_account_email}")
      FILTER USING (
        region IN (
          SELECT region
          FROM `${var.project_id}.${var.staged_dataset_id}.region_access_map`
          WHERE user_email = SESSION_USER()
        )
      );
    SQL
    use_legacy_sql = false
  }

  depends_on = [
    google_bigquery_table.student_onboarding,
    google_bigquery_table.region_access_map,
  ]

  lifecycle {
    ignore_changes = [job_id] # avoid re-triggering the job on every plan
  }
}
