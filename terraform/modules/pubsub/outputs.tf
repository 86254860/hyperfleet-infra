# =============================================================================
# Pub/Sub Resources Output (Hierarchical)
# =============================================================================
output "pubsub_resources" {
  description = "Complete Pub/Sub resources organized by topic, including subscriptions"
  value = {
    for topic_name, topic_config in local.topics : topic_name => {
      topic_name     = google_pubsub_topic.topics[topic_name].name
      topic_id       = google_pubsub_topic.topics[topic_name].id
      dlq_topic_name = var.enable_dead_letter ? google_pubsub_topic.dead_letter[topic_name].name : null

      subscriptions = {
        for adapter_name, adapter_config in topic_config.adapter_subscriptions :
        adapter_name => {
          name                  = google_pubsub_subscription.subscriptions["${topic_name}-${adapter_name}"].name
          id                    = google_pubsub_subscription.subscriptions["${topic_name}-${adapter_name}"].id
          service_account_email = google_service_account.adapters[adapter_name].email
          ack_deadline_seconds  = adapter_config.ack_deadline_seconds
        }
      }
    }
  }
}

# =============================================================================
# Service Account Outputs
# =============================================================================
output "sentinel_service_account" {
  description = "Sentinel GCP service account email (shared across all topics)"
  value       = google_service_account.sentinel.email
}

output "adapter_service_accounts" {
  description = "Map of adapter names to their GCP service account emails"
  value = {
    for adapter in local.unique_adapters : adapter => google_service_account.adapters[adapter].email
  }
}

# =============================================================================
# Helm Values Snippet
# =============================================================================
output "helm_values_snippet" {
  description = "Snippet to add to Helm values for Workload Identity annotations and Pub/Sub configuration"
  value       = <<-EOT
%{for topic_name, topic_config in local.topics~}
# ============================================================================
# Services for ${replace(title(replace(topic_name, "-", " ")), " ", " ")} Topic
# Topic name: ${google_pubsub_topic.topics[topic_name].name}
# DLQ topic name: ${var.enable_dead_letter ? google_pubsub_topic.dead_letter[topic_name].name : "N/A (DLQ disabled)"}
# ============================================================================
# Sentinel (publishes to ${topic_name} topic)
${topic_name}-sentinel:
  serviceAccount:
    name: ${var.sentinel_k8s_sa_name}
    annotations:
      iam.gke.io/gcp-service-account: ${google_service_account.sentinel.email}
  broker:
    type: googlepubsub
    topic: ${google_pubsub_topic.topics[topic_name].name}
    googlepubsub:
      projectId: ${var.project_id}

# Adapters (subscribe to ${topic_name} topic)
%{for adapter_name, adapter_config in topic_config.adapter_subscriptions~}
${topic_name}-${adapter_name}-adapter:
  serviceAccount:
    name: ${adapter_name}-adapter
    annotations:
      iam.gke.io/gcp-service-account: ${google_service_account.adapters[adapter_name].email}
  broker:
    type: googlepubsub
    googlepubsub:
      projectId: ${var.project_id}
      topic: ${google_pubsub_topic.topics[topic_name].name}
      subscription: ${google_pubsub_subscription.subscriptions["${topic_name}-${adapter_name}"].name}
%{if var.enable_dead_letter~}
      deadLetterTopic: ${google_pubsub_topic.dead_letter[topic_name].name}
%{endif~}

%{endfor~}
%{endfor~}
  EOT
}
