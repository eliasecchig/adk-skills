# Observability & Monitoring

> **Assumes `/adk-scaffold` scaffolding.** Observability infrastructure is provisioned by Terraform in scaffolded projects.

## Two Tiers of Observability

| Tier | What | Scope | Default State |
|------|------|-------|---------------|
| **Agent Telemetry Events (Cloud Trace)** | OpenTelemetry traces and spans for agent operations — execution flow, latency, errors | All templates, all environments | Always enabled, no config needed |
| **Prompt-Response Logging** | GenAI interactions (model name, tokens, timing) exported to GCS (JSONL), BigQuery (external tables), and Cloud Logging (dedicated bucket) | ADK-based agents only | Disabled locally, enabled in deployed environments |

## Agent Telemetry Events (Cloud Trace)

Always-on distributed tracing via `otel_to_cloud=True` in the FastAPI app. Tracks requests through LLM calls and tool executions with latency analysis and error visibility.

View traces: **Cloud Console → Trace → Trace explorer**

No configuration required. Works in local dev (`make playground`) and all deployed environments.

## Prompt-Response Logging

### Privacy Mode

Prompt-response logging is **privacy-preserving by default** — only metadata (tokens, model name, timing) is logged. Prompts and responses are NOT captured (`NO_CONTENT` mode). This is controlled by `OTEL_INSTRUMENTATION_GENAI_CAPTURE_MESSAGE_CONTENT`:

| Value | Behavior |
|-------|----------|
| `false` | Logging disabled |
| `NO_CONTENT` | Enabled, metadata only (default in deployed environments) |
| `true` | Enabled with full content (not recommended for production) |

For Agent Engine: the platform requires `true` during deployment, but the app overrides to `NO_CONTENT` at runtime.

### Behavior by Environment

| Environment | Prompt-Response Logging | Why |
|-------------|------------------------|-----|
| Local dev (`make playground`) | Disabled | No `LOGS_BUCKET_NAME` set |
| Dev (Terraform deployed) | Enabled (`NO_CONTENT`) | Terraform sets env vars |
| Staging / Production | Enabled (`NO_CONTENT`) | Terraform sets env vars |

To enable locally, set `LOGS_BUCKET_NAME` and `OTEL_INSTRUMENTATION_GENAI_CAPTURE_MESSAGE_CONTENT=NO_CONTENT` before running `make playground`.

To disable in a deployed environment, set `OTEL_INSTRUMENTATION_GENAI_CAPTURE_MESSAGE_CONTENT=false` in `deployment/terraform/service.tf` and re-apply.

### Infrastructure

All provisioned automatically by `deployment/terraform/telemetry.tf`:

- **Cloud Logging bucket** — 10-year retention, analytics enabled, dedicated to GenAI telemetry
- **Log sinks** — Route GenAI inference logs and feedback logs to the telemetry bucket
- **Linked dataset** — Cloud Logging bucket linked to BigQuery for SQL access
- **GCS logs bucket** — Stores completions as NDJSON
- **BigQuery dataset** — External tables over GCS data, linked dataset from Cloud Logging
- **BigQuery connection** — Service account for GCS access from BigQuery

Check `deployment/terraform/telemetry.tf` for exact configuration. IAM bindings are in `iam.tf`.

### Environment Variables

Set automatically by Terraform on the deployed service:

| Variable | Purpose |
|----------|---------|
| `LOGS_BUCKET_NAME` | GCS bucket for completions and logs. Required to enable prompt-response logging |
| `OTEL_INSTRUMENTATION_GENAI_CAPTURE_MESSAGE_CONTENT` | Controls logging state and content capture |
| `BQ_ANALYTICS_DATASET_ID` | BigQuery dataset for telemetry |
| `BQ_ANALYTICS_CONNECTION_ID` | BigQuery connection for GCS access |
| `GENAI_TELEMETRY_PATH` | Optional: override upload path within bucket (default: `completions`) |

### Verifying Telemetry

After deploying, verify prompt-response logging is working:

```bash
PROJECT_ID="your-dev-project-id"
PROJECT_NAME="your-project-name"

# Check GCS data
gsutil ls gs://${PROJECT_ID}-${PROJECT_NAME}-logs/completions/

# Check Cloud Logging bucket
gcloud logging buckets describe ${PROJECT_NAME}-genai-telemetry \
  --location=us-central1 --project=${PROJECT_ID}

# Query BigQuery
bq query --use_legacy_sql=false \
  "SELECT * FROM \`${PROJECT_ID}.${PROJECT_NAME}_telemetry.completions\` LIMIT 10"
```

If data is not appearing: check `LOGS_BUCKET_NAME` is set, verify SA has `storage.objectCreator` on the bucket, check application logs for telemetry setup warnings.

## BigQuery Agent Analytics Plugin (Opt-In)

An optional plugin for ADK-based agents that logs structured agent events (LLM interactions, tool calls, outcomes) directly to BigQuery. Enables conversational analytics, LLM-as-judge evals, and custom dashboards.

Enable with `--bq-analytics` at scaffold time. Infrastructure is provisioned automatically by Terraform. Configuration is in `app/agent.py`. For full details, fetch `https://google.github.io/adk-docs/runtime/plugins.md` via WebFetch.
