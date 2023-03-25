locals {
    project_id    = var.project_id
    env_vars = {
      PROJECT_ID = var.project_id
      UPLOAD_BUCKET = google_storage_bucket.pdf_bucket.name
    }
}

# https://cloud.google.com/run/docs/troubleshooting#service-agent
resource "google_project_iam_member" "project" {
  project = var.project_id
  role    = "roles/run.invoker"
  member  = "service-${data.google_project.function_project.number}@serverless-robot-prod.iam.gserviceaccount.com"
}

resource "google_cloudfunctions2_function" "function" {
  project  = var.project_id
  name     = "generate-pdfs"
  location = var.region
  

  build_config {
    runtime     = "python39"
    entry_point = "generate_pdfs"

    environment_variables = {
      BUILD_CONFIG_TEST = "build_test"
    }

    source {
      storage_source {
        bucket = google_storage_bucket.source_code.name
        object = google_storage_bucket_object.reporting.name
      }
    }
  }
    
  service_config {
    min_instance_count = 0
    max_instance_count = 1
    max_instance_request_concurrency = 1
    available_cpu = 2
    available_memory   = "8192Mi"
    timeout_seconds    = 3600
    ingress_settings   = "ALLOW_ALL"
    all_traffic_on_latest_revision = true
    environment_variables = local.env_vars
  }
}
