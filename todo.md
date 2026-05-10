# GitHub Bot — Project Audit & TODO

## What Has Been Achieved

- **Webhook receiver** — `POST /webhooks/github` accepts GitHub events with PR metadata and raw diff
- **Diff parser** — Splits raw git diff into per-file before/after chunks (implemented in both controller and job)
- **Background job processing** — `GeminiReviewJob` handles review asynchronously via Solid Queue
- **GitHub integration** — `GitHubService` posts review comments back to the PR
- **Gemini orchestrator** — `GeminiService` + `AgentOrchestrator` uses Gemini 2.5 Flash to create a review plan and synthesize agent output into a final comment
- **3 specialized agents** — SecurityAgent, CodeQualityAgent, PerformanceAgent inherit from BaseAgent and call Ollama locally
- **Agentic loop** — Each agent runs a multi-turn conversation with the LLM; replies with `{ message, tool_call, done }` JSON; can call `get_file` or `search_codebase` tools before concluding (max 5 tool calls per agent)
- **`config/agents.yml`** — Single config file holds all system prompts (per agent), orchestrator prompts, model names, temperature, and max_tool_calls
- **Repo access tools** — `GitHubService#get_file_content` and `#search_code` let agents fetch full files or search the codebase mid-review
- **Ollama integration** — `OllamaService` connects to local LLM server for small-model inference
- **HTTP client** — `HttpService` wraps Net::HTTP with error handling and JSON parsing
- **CI pipeline** — GitHub Actions: Brakeman security scan, RuboCop lint, Rails test suite
- **GitHub Actions bot trigger** — `actions_file.yml` triggers on `@my-bot` mentions, extracts PR diff, and calls the webhook
- **Docker + Kamal deployment** — Production-ready containerized deploy config
- **Solid Queue/Cache/Cable** — Rails 8 Omakase stack fully configured

---

## What Still Needs to Be Done

### Core Features

| Task | Priority | Feasibility (1=easy, 5=hard) | Notes |
|------|----------|-------------------------------|-------|
| **Orchestrator: selective file routing** | High | 3 | Gemini's review plan currently isn't used to filter which files each agent receives — all agents get all files. Need to parse the plan and route relevant files to relevant agents only. |
| **Webhook signature verification** | High | 2 | GitHub sends `X-Hub-Signature-256` header — must verify HMAC-SHA256 to reject forged requests. Add `GITHUB_WEBHOOK_SECRET` env var. |
| ~~**Agent response parsing**~~ | ~~Medium~~ | ~~2~~ | ~~Done~~ — agents now respond with structured `{ message, tool_call, done }` JSON; base agent parses and falls back gracefully on invalid JSON. |
| ~~**Testing & Documentation agents**~~ | ~~Low~~ | ~~1~~ | ~~Done~~ — removed. |
| ~~**Configurable model per agent**~~ | ~~Low~~ | ~~2~~ | ~~Done~~ — `config/agents.yml` holds model, temperature, max_tool_calls for agents and model for orchestrator. |
| **Rate limit handling** | Medium | 2 | No retry/backoff for GitHub API 429s or Gemini quota errors. Add to HttpService or individual services. |
| **Env var validation at startup** | Medium | 1 | Raise clear errors on boot if `GEMINI_API_KEY` / `GITHUB_TOKEN` are missing. Add to an initializer. |
| **Review history / DB models** | Low | 3 | Schema is empty. If you want to track past reviews, store metrics, or deduplicate: need `reviews` and `pull_requests` tables. Not required for MVP. |

### Code Quality / Cleanup

| Task | Priority | Feasibility | Notes |
|------|----------|-------------|-------|
| **Deduplicate diff parser** | High | 1 | `parse_diff` is copy-pasted identically in `WebhooksController` and `GeminiReviewJob`. Extract to a `DiffParser` service or concern. |
| **Remove TestingAgent and DocumentationAgent** | Medium | 1 | They are outside the stated spec (security / performance / quality). Either remove or explicitly document why they are included. |
| **`actions_file.yml` → `.github/workflows/`** | Medium | 1 | The bot trigger workflow lives at the root as `actions_file.yml`. It won't be picked up by GitHub Actions unless moved to `.github/workflows/`. |
| **Webhook controller logic** | Medium | 2 | Controller does diff parsing inline. This should be delegated to a service/job entirely — controller should only validate input and enqueue. |
| **Gemini prompt engineering** | Medium | 3 | Current prompts are functional but the orchestrator's planning prompt doesn't enforce a structured format that can be reliably parsed for file routing. |
| **OllamaService timeout** | Low | 1 | 5-minute read timeout is a magic number. Make it configurable via `OLLAMA_TIMEOUT` env var. |
| **Job retry strategy** | Low | 1 | `GeminiReviewJob` retries 3× with polynomial backoff but has no dead-letter handling or alerting on final failure. |

---

## Services — What They Do & Status

### `lib/http_service.rb`
Generic HTTP client. Handles GET/POST/PUT/DELETE, JSON parsing, and raises `RequestError` on failures.
**Status:** Clean and reusable. No changes needed.

### `lib/github_service.rb`
Calls GitHub API v3. Currently has `post_comment` and `get_pull_request`.
**Status:** Functional. Missing: rate limit handling, webhook signature verification (belongs in controller but uses same secret).

### `lib/gemini_service.rb`
Wraps Gemini 2.5 Flash API. Has `code_review`, `generate_content`, `chat`.
**Status:** Functional. The `code_review` method builds a prompt but the result is not used for file routing (yet). The `chat` method is unused — consider removing.

### `lib/ollama_service.rb`
Local LLM client for Ollama server (`http://localhost:11434`). Has `generate`, `chat`, `check_model_availability`.
**Status:** Functional. `check_model_availability` is never called before inference — agents will silently fail if the model isn't loaded. Should be called on startup or before first use.

### `lib/agent_orchestrator.rb`
Coordinates the review: asks Gemini for a plan → runs all agents → asks Gemini to synthesize → returns markdown comment.
**Status:** Works end-to-end BUT the planning step output is discarded — all files go to all agents regardless of plan. The selective routing logic is the biggest missing feature. Also runs agents sequentially with a 0.5s sleep; consider parallelizing.

### `lib/agents/base_agent.rb`
Abstract base. Holds Ollama connection and helper methods `format_diff_for_prompt` and `query_ollama`.
**Status:** Clean. No changes needed.

### `lib/agents/security_agent.rb`
Reviews for OWASP-style vulnerabilities (SQLi, XSS, CSRF, mass assignment, credential exposure, etc.).
**Status:** Prompt is well-targeted. No changes needed.

### `lib/agents/code_quality_agent.rb`
Reviews for Rails conventions, SOLID, DRY, naming, complexity.
**Status:** Prompt is well-targeted. No changes needed.

### `lib/agents/performance_agent.rb`
Reviews for N+1 queries, missing indexes, memory leaks, inefficient loops.
**Status:** Prompt is well-targeted. No changes needed.

### `lib/agents/testing_agent.rb`
Reviews for missing tests, edge cases, test quality.
**Status:** Outside original spec. Decide: keep or remove.

### `lib/agents/documentation_agent.rb`
Reviews for missing docs, unclear names, inline comments.
**Status:** Outside original spec. Decide: keep or remove.

### `app/jobs/gemini_review_job.rb`
Background job: parse diff → orchestrate agents → post GitHub comment.
**Status:** Works. Contains duplicated diff parser — extract it.

### `app/controllers/webhooks_controller.rb`
Entry point for GitHub webhooks. Parses diff inline, enqueues job.
**Status:** Works. Contains duplicated diff parser and inline business logic — slim it down.

---

## Immediate Action Items (Quick Wins)

1. **Move `actions_file.yml` to `.github/workflows/bot_trigger.yml`** — otherwise the GitHub Actions trigger never fires (feasibility: 1)
2. **Extract `parse_diff` into `lib/diff_parser.rb`** — remove the duplication between controller and job (feasibility: 1)
3. **Add webhook HMAC verification** in `WebhooksController` before processing (feasibility: 2)
4. **Add env var presence check initializer** so missing keys fail loudly at boot (feasibility: 1)
5. **Wire Gemini plan output into agent file routing** — the biggest architectural gap (feasibility: 3)
