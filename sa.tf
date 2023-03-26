locals {
      project_iam_roles = [
    "roles/bigquery.admin",
    "roles/secretmanager.secretAccessor",
    "roles/storage.admin",
    "roles/run.invoker",
    "roles/iam.serviceAccountTokenCreator",
    "roles/cloudtrace.agent",
    "roles/cloudfunctions.admin",
    "roles/logging.logWriter",
    "roles/stackdriver.resourceMetadata.writer",
    "roles/monitoring.metricWriter",
    "roles/iam.serviceAccountUser",
    "roles/artifactregistry.reader",
    "roles/artifactregistry.writer",
    "roles/cloudtasks.admin"
  ]
}

resource "google_service_account" "function" {
  account_id   = "sa-pdf-${data.google_project.function_project.number}"
  display_name = "SA for the PDF Cloud Function"
  project      = var.project_id
}

resource "google_project_iam_member" "set-roles" {
  for_each = toset(local.project_iam_roles)

  project = var.project_id
  role    = each.value
  member  = "serviceAccount:${google_service_account.function.email}"
}
