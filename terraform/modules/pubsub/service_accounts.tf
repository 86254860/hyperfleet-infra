# =============================================================================
# Sentinel Service Account (Publisher) - Single account for all topics
# =============================================================================
resource "google_service_account" "sentinel" {
  account_id   = substr("sentinel-${var.developer_name}", 0, 30)
  display_name = "HyperFleet Sentinel"
  description  = "Service account for HyperFleet Sentinel to publish events to all Pub/Sub topics"
  project      = var.project_id
}

# Grant Sentinel permission to publish to all topics
resource "google_pubsub_topic_iam_member" "sentinel_publisher" {
  for_each = local.topics

  topic   = google_pubsub_topic.topics[each.key].name
  role    = "roles/pubsub.publisher"
  member  = "serviceAccount:${google_service_account.sentinel.email}"
  project = var.project_id
}

# Grant Sentinel permission to view all topics metadata (needed to check if topic exists)
resource "google_pubsub_topic_iam_member" "sentinel_viewer" {
  for_each = local.topics

  topic   = google_pubsub_topic.topics[each.key].name
  role    = "roles/pubsub.viewer"
  member  = "serviceAccount:${google_service_account.sentinel.email}"
  project = var.project_id
}

# Workload Identity binding for Sentinel
# Allows the Kubernetes service account to impersonate the GCP service account
resource "google_service_account_iam_member" "sentinel_workload_identity" {
  service_account_id = google_service_account.sentinel.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "serviceAccount:${var.project_id}.svc.id.goog[${var.kubernetes_namespace}/${var.sentinel_k8s_sa_name}]"
}

# =============================================================================
# Adapter Service Accounts (Subscribers)
# =============================================================================
resource "google_service_account" "adapters" {
  for_each = local.unique_adapters

  account_id   = substr("${each.key}-${var.developer_name}", 0, 30)
  display_name = "HyperFleet Adapter - ${each.key}"
  description  = "Service account for HyperFleet ${each.key} adapter to consume events from Pub/Sub"
  project      = var.project_id
}

# Grant Adapter permission to subscribe to their subscriptions
resource "google_pubsub_subscription_iam_member" "adapters_subscriber" {
  for_each = local.all_subscriptions

  subscription = google_pubsub_subscription.subscriptions[each.key].name
  role         = "roles/pubsub.subscriber"
  member       = "serviceAccount:${google_service_account.adapters[each.value.adapter_name].email}"
  project      = var.project_id
}

# Grant Adapter permission to view subscriptions (needed for some operations)
resource "google_pubsub_subscription_iam_member" "adapters_viewer" {
  for_each = local.all_subscriptions

  subscription = google_pubsub_subscription.subscriptions[each.key].name
  role         = "roles/pubsub.viewer"
  member       = "serviceAccount:${google_service_account.adapters[each.value.adapter_name].email}"
  project      = var.project_id
}

# Workload Identity binding for Adapters
resource "google_service_account_iam_member" "adapters_workload_identity" {
  for_each = local.unique_adapters

  service_account_id = google_service_account.adapters[each.key].name
  role               = "roles/iam.workloadIdentityUser"
  member             = "serviceAccount:${var.project_id}.svc.id.goog[${var.kubernetes_namespace}/${each.key}-adapter]"
}

# =============================================================================
# Dead Letter Queue Permissions (if enabled)
# =============================================================================

# Grant Pub/Sub service account permission to publish to DLQ topics
# This is required for the dead letter policy to work
resource "google_pubsub_topic_iam_member" "pubsub_dlq_publisher" {
  for_each = var.enable_dead_letter ? local.topics : {}

  topic   = google_pubsub_topic.dead_letter[each.key].name
  role    = "roles/pubsub.publisher"
  member  = "serviceAccount:service-${data.google_project.current.number}@gcp-sa-pubsub.iam.gserviceaccount.com"
  project = var.project_id
}

# Grant Pub/Sub service account permission to acknowledge messages from all subscriptions
resource "google_pubsub_subscription_iam_member" "pubsub_dlq_subscriber" {
  for_each = var.enable_dead_letter ? local.all_subscriptions : {}

  subscription = google_pubsub_subscription.subscriptions[each.key].name
  role         = "roles/pubsub.subscriber"
  member       = "serviceAccount:service-${data.google_project.current.number}@gcp-sa-pubsub.iam.gserviceaccount.com"
  project      = var.project_id
}

# Get current project info for Pub/Sub service account
data "google_project" "current" {
  project_id = var.project_id
}
