locals {
  apis = [
    "compute.googleapis.com",
    "cloudresourcemanager.googleapis.com",
    "cloudbilling.googleapis.com",
    "vpcaccess.googleapis.com",
    "servicenetworking.googleapis.com",
    "storage-api.googleapis.com",
    "storage-component.googleapis.com",
    "cloudfunctions.googleapis.com",
    "cloudbuild.googleapis.com",
    "drive.googleapis.com",
    "artifactregistry.googleapis.com",
    "run.googleapis.com",
    "cloudtasks.googleapis.com"
  ]
}

data "google_project" "function_project" {
  project_id = var.project_id
}

resource "google_project_service" "project" {
  for_each = toset(local.apis)

  project = var.project_id
  service = each.value

  disable_dependent_services = true
  disable_on_destroy = false
}


resource "google_storage_bucket" "source_code" {
  project = var.project_id

  name          = "source-code-${data.google_project.function_project.number}"
  location      = var.region
  storage_class = "STANDARD"
  force_destroy = true

  uniform_bucket_level_access = true

  labels = {
    purpose = "source_code"
  }
  depends_on = [
    google_project_service.project
  ]
}

resource "google_storage_bucket" "pdf_bucket" {
  project = var.project_id

  name          = "pdfs-${data.google_project.function_project.number}"
  location      = var.region
  storage_class = "STANDARD"
  force_destroy = true

  uniform_bucket_level_access = true

  labels = {
    purpose = "pdfs"
  }
  depends_on = [
    google_project_service.project
  ]
}

data "archive_file" "report_archive" {
  type        = "zip"
  source_dir  = "../functions/generate_pdfs"
  output_path = "../functions/generate_pdfs.zip"
  excludes = ["../functions/generate_reports/__pycache__",
  "../functions/generate_reports/common/__pycache__",
  "../functions/generate_reports/venv"]
}

resource "google_storage_bucket_object" "reporting" {
  name         = "generate-pdfs-${data.archive_file.report_archive.output_md5}.zip"
  content_type = "application/zip"
  bucket       = google_storage_bucket.source_code.name
  source       = data.archive_file.report_archive.output_path
  depends_on = [
    data.archive_file.report_archive,
    google_storage_bucket.source_code,
    google_storage_bucket.pdf_bucket,
  ]
}
