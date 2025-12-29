locals {
  topic_name     = var.topic_name != "" ? var.topic_name : "${var.namespace}-${var.resource_type}-${var.developer_name}"
  dlq_topic_name = "${local.topic_name}-dlq"

  # Create map of adapters with their configurations
  # Key: adapter name, Value: subscription and service account names
  adapter_configs = {
    for adapter in var.adapters : adapter => {
      subscription_name        = "${var.namespace}-${adapter}-adapter-${var.developer_name}"
      gcp_service_account_name = substr("${adapter}-${var.developer_name}", 0, 30)
      k8s_service_account_name = "${adapter}-adapter"
    }
  }

  common_labels = merge(var.labels, {
    managed-by = "terraform"
    component  = "hyperfleet-pubsub"
  })
}

# =============================================================================
# Pub/Sub Topic for Events
# =============================================================================
resource "google_pubsub_topic" "events" {
  name    = local.topic_name
  project = var.project_id

  # Retain messages for replay (optional)
  message_retention_duration = var.message_retention_duration

  labels = local.common_labels
}

# =============================================================================
# Dead Letter Topic (for failed messages)
# =============================================================================
resource "google_pubsub_topic" "dead_letter" {
  count   = var.enable_dead_letter ? 1 : 0
  name    = local.dlq_topic_name
  project = var.project_id

  labels = local.common_labels
}

# =============================================================================
# Pub/Sub Subscriptions for Adapters
# =============================================================================
resource "google_pubsub_subscription" "adapters" {
  for_each = local.adapter_configs

  name    = each.value.subscription_name
  topic   = google_pubsub_topic.events.name
  project = var.project_id

  # ACK deadline (how long adapter has to acknowledge)
  ack_deadline_seconds = var.ack_deadline_seconds

  # Message retention (how long to keep unacked messages)
  message_retention_duration = var.message_retention_duration

  # Don't auto-delete subscription
  expiration_policy {
    ttl = ""
  }

  # Dead letter policy
  dynamic "dead_letter_policy" {
    for_each = var.enable_dead_letter ? [1] : []
    content {
      dead_letter_topic     = google_pubsub_topic.dead_letter[0].id
      max_delivery_attempts = var.max_delivery_attempts
    }
  }

  # Retry policy
  retry_policy {
    minimum_backoff = "10s"
    maximum_backoff = "600s"
  }

  labels = local.common_labels
}

# =============================================================================
# Dead Letter Subscription (for monitoring failed messages)
# =============================================================================
resource "google_pubsub_subscription" "dead_letter" {
  count   = var.enable_dead_letter ? 1 : 0
  name    = "${local.dlq_topic_name}-sub"
  topic   = google_pubsub_topic.dead_letter[0].name
  project = var.project_id

  ack_deadline_seconds       = 60
  message_retention_duration = "604800s" # 7 days

  expiration_policy {
    ttl = ""
  }

  labels = local.common_labels
}
