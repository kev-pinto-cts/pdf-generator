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
  member  = "serviceAccount:service-${data.google_project.function_project.number}@serverless-robot-prod.iam.gserviceaccount.com"
}


resource "google_cloudfunctions2_function" "function" {
  project  = var.project_id
  name     = "generate-pdfs"
  location = var.region
  
  build_config {
    runtime     = "python311"
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
    service_account_email = google_service_account.function.email
  }
}

resource "google_cloud_tasks_queue" "reporting_queue" {
  name = "pdf-queue"
  project = var.project_id
  location = var.region

  rate_limits {
    max_concurrent_dispatches = 1
    max_dispatches_per_second = 2
  }

  retry_config {
    max_attempts = 1
    max_retry_duration = "4s"
    max_backoff = "3s"
    min_backoff = "2s"
    max_doublings = 1
  }

  stackdriver_logging_config {
    sampling_ratio = 0.9
  }
  depends_on = [
    google_cloudfunctions2_function.function
  ]
}




resource "google_cloudfunctions2_function" "task_function" {
  project  = var.project_id
  name     = "main-function"
  location = var.region
  

  build_config {
    runtime     = "python311"
    entry_point = "create_http_task"

    environment_variables = {
      BUILD_CONFIG_TEST = "build_test"
    }

    source {
      storage_source {
        bucket = google_storage_bucket.source_code.name
        object = google_storage_bucket_object.task_storage_object.name
      }
    }
  }

service_config {
    min_instance_count = 0
    max_instance_count = 1
    max_instance_request_concurrency = 1
    available_cpu = 2
    available_memory   = "512Mi"
    timeout_seconds    = 540
    ingress_settings   = "ALLOW_ALL"
    all_traffic_on_latest_revision = true
    environment_variables = merge(local.env_vars,
                            {
                              PDF_GENERATOR_URI=google_cloudfunctions2_function.function.service_config[0].uri
                              PDF_TASK_Q = google_cloud_tasks_queue.reporting_queue.name
                              SA_EMAIL = google_service_account.function.email
                            }
                            )
    service_account_email = google_service_account.function.email
  }
  depends_on = [
    google_cloudfunctions2_function.function,
    google_cloud_tasks_queue.reporting_queue
  ]
}



