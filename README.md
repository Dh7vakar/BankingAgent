# Simulated Real-Time Banking Architecture with Multi-Agent Automation

> **SIMULATED. Demo use only.** Every customer, account, transaction, loan, KYC/AML result and external service in this project is synthetic. No real banking system, data or money is involved.

A complete, runnable MVP of a multi-agent AI banking assistant: a LangGraph **supervisor** routes requests to **six specialist agents** (Customer, Risk/Fraud, Credit/Loan, Compliance, Product/Policy, Notification) that act only through **governed tools**, with an **AI gateway** (PII masking, guardrails, prompt store, model routing, budget), **hybrid RAG** with citations, **human-in-the-loop approvals**, a **FastAPI** layer, a **Streamlit** UI with a live agent-trace panel, and an **evaluation suite**. It follows the 9-layer reference architecture in the assignment brief.

---

## 1. What was verified (and what was not)

| Verified in the build environment (Python 3.12) | Status |
|---|---|
| 85 automated tests (`pytest`) covering tools, permissions, fraud scoring, gateway, RAG, agents, API, MCP server, evaluation, UI | all pass |
| All 7 required use cases end to end (`scripts/run_demo.py`, UI via Streamlit's `AppTest`) | work |
| Evaluation suite: 19 queries on a fresh deterministic database | 19/19 pass; routing 100%, tool-call correctness 100%, groundedness 100% |
| HTTP provider code for Anthropic, Ollama and OpenAI-compatible APIs (OpenAI, Groq, Gemini, OpenRouter, ...), incl. fallback chain, PII masking and cost accounting | tested against mocked HTTP only |

| **Not** verified | Why |
|---|---|
| Live calls to any LLM provider (Anthropic, OpenAI, Groq, Gemini, Ollama, ...) | no API keys / no Ollama in the build environment. Request shapes, PII masking, model routing and cost accounting are unit-tested with a mocked transport. Exact model names and provider-specific quirks need a real call from you. |
| Docker build (`Dockerfile`, `docker-compose.yml`) | Docker was not available. |
| UI in end-user browsers | the UI is tested with Streamlit's headless `AppTest` and was rendered and visually reviewed in headless Chromium at 1600 px width; other browsers, mobile and small-screen layouts were not checked. |
| MCP server over a network transport | tested in-process (list tools, call tools, permission denial). |

**Reading the evaluation numbers honestly:** the 19 test queries were written by the same author as the system, and the default `mock` provider routes with deterministic rules. 100% therefore shows the system behaves as designed, not that a real LLM would route this well. Re-run `python -m app.eval.runner` with a real provider to measure that.

---

## 2. Execution steps

### Prerequisites
Python 3.11 or newer (developed and tested on 3.12). No API key and no internet access are needed to run the demo.

### Step 1: install
```bash
cd banking-agents
python -m venv .venv
source .venv/bin/activate            # Windows: .venv\Scripts\activate
pip install -r requirements.txt
cp .env.example .env                  # optional; defaults already run fully offline
```

### Step 2: run the tests (confirms the install)
```bash
python -m pytest -q                   # expect: 85 passed
```

### Step 3: start the app (one command)
```bash
streamlit run ui/app.py
```
Open http://localhost:8501. The database (`app/data/bank.db`) is created and seeded automatically on first start. The UI runs the backend **in-process**, so no second terminal is needed.

### Step 4 (optional): run the API server, and point the UI at it
```bash
uvicorn app.api.main:app --reload --port 8000       # Swagger docs at http://localhost:8000/docs
# in a second terminal:
API_URL=http://localhost:8000 streamlit run ui/app.py
```
Quick API check with curl:
```bash
TOKEN=$(curl -s localhost:8000/auth/login -H 'content-type: application/json' \
  -d '{"persona":"customer","customer_id":"C-1003"}' | python -c "import sys,json;print(json.load(sys.stdin)['token'])")
curl -s localhost:8000/chat -H "Authorization: Bearer $TOKEN" -H 'content-type: application/json' \
  -d '{"message":"I see a $4,200 charge in Singapore I did not make."}'
```

### Step 5: other commands
| Command | What it does |
|---|---|
| `python scripts/run_demo.py --print-only` | runs the 7 use cases in the terminal on a throwaway database |
| `python scripts/run_demo.py` | same, and rewrites `docs/demo_script.md` with the real outputs |
| `python -m app.eval.runner` | runs the 19-case evaluation on a fresh database, stores the result, rewrites `docs/eval_report.md` |
| `python -m app.data.seed` | wipes and re-seeds `app/data/bank.db` (also clears traces and audit rows) |
| `python -m app.tools.mcp_server` | serves the 12 governed tools over MCP (stdio) |
| `make test`, `make ui`, `make api`, `make eval`, `make demo` | shortcuts for the above |
| `docker compose up --build` | API on :8000 and UI on :8501 (untested, see section 1) |

---

## 3. Running each required use case

In the UI, click the numbered button in the sidebar: it selects the right channel and customer and sends the query. Open **Agent trace** on the right to see the supervisor's trajectory. Exact expected outputs are in `docs/demo_script.md`.

| # | Channel / customer | Query | Expected |
|---|---|---|---|
| 1 | Customer / C-1001 | Show my last 5 transactions and my account balance. | Customer Agent; checking $48,250.75; 5 transactions |
| 2 | Customer / C-1003 | I see a $4,200 charge in Singapore I didn't make. | Fraud score 95/100 HIGH with reasons; **Approve** to block the card; SMS sent by Notification Agent |
| 3 | Customer / C-1001 | Can I get a $20,000 personal loan? | APPROVED, EMI $502.46, cites `loan_policy.md`. For C-1002: DECLINED (score 612) |
| 4 | Customer / C-1001 | Check if I'm eligible for a home loan and review my account for suspicious activity. | Credit and Fraud agents both run; merged answer. Try C-1009 for flagged transactions |
| 5 | **RM** / any | Is customer C-1007 KYC compliant? Any AML flags? | NOT COMPLIANT: KYC expired, PEP match, with SOP citations |
| 6 | Customer / C-1001 | Transfer $15,000 to account ACC-1010-CHK | Pre-transfer risk check (MEDIUM 65), then **approval prompt**; Approve to execute and notify |
| 7 | Customer / C-1001 | What documents are required for a home loan? | Policy answer with `[loan_policy.md › 4. Documents Required]` |

Safety demos (sidebar, "Safety demos"): prompt injection is blocked; an SSN in the query is masked in the trace. Also try asking a Customer-channel question about another customer (blocked), or the same transfer as an RM (denied by persona policy).

**Dashboard tab** (switch the channel to RM, Call Center or Fraud Analyst): audit log with filters, tokens/cost per agent and per model, P50/P95 latency, error rate, tool failure counts, fraud alerts, and a button that runs the evaluation suite.

**Planted demo data** (24 customers, 680 transactions, seed 42): C-1003 Singapore charge on a new device; C-1005 six rapid transfers to a new payee; C-1009 foreign new-device login then a purchase; C-1007 expired KYC with a PEP flag; C-1012 five cash deposits just under 10,000; C-1002 low credit score; C-1001 strong credit and a $48,250.75 checking balance.

---

## 4. Configuration (`.env`)

| Variable | Default | Meaning |
|---|---|---|
| `LLM_PROVIDER` | `mock` | `mock` (offline), `anthropic`, `openai`, `groq`, `gemini`, `openrouter`, `deepseek`, `mistral`, `together`, `openai_compat` (any other compatible server), or `ollama` |
| `LLM_API_KEY` | empty | the API key for the provider named above |
| `LLM_BASE_URL` | preset | overrides the preset URL (required for `openai_compat`) |
| `LLM_FALLBACK` | `ollama,mock` | providers tried, in order, if the primary fails; `mock` is always the last resort |
| `ROUTER_MODEL` | `claude-haiku-5-5` | cheap/fast model used for intent routing. **Change to your provider's model name** |
| `REASONING_MODEL` | `claude-sonnet-5-5` | stronger model used to compose answers. **Change to your provider's model name** (may equal `ROUTER_MODEL`) |
| `ANTHROPIC_API_KEY` | empty | alternative to `LLM_API_KEY` when `LLM_PROVIDER=anthropic` |
| `LLM_MAX_TOKENS_PARAM`, `LLM_JSON_MODE` | `max_tokens`, `false` | provider quirks: some newer OpenAI models need `max_completion_tokens`; JSON mode is only sent if enabled |
| `LLM_PRICE_IN`, `LLM_PRICE_OUT` | unset | USD per 1M tokens, so the cost dashboard is right for your model |
| `OLLAMA_URL`, `OLLAMA_MODEL` | `http://localhost:11434`, `llama3.1` | local fallback model |
| `HITL_TRANSFER_THRESHOLD` | `10000` | transfers at or above this need human approval |
| `LOAN_HITL_THRESHOLD` | `50000` | loan approvals above this need a credit officer |
| `REQUEST_TOKEN_BUDGET` | `12000` | max LLM tokens per chat request |
| `RATE_LIMIT_PER_MIN` | `60` | API requests per token per minute |
| `SIM_FAILURE_RATE`, `SIM_LATENCY_MS` | `0.05`, `20,120` | failure probability and latency range of the simulated external services |
| `BANK_DB_PATH` | `app/data/bank.db` | SQLite file location |
| `API_URL` | unset | if set, the UI uses the HTTP API instead of in-process calls |

### Switching the LLM provider or API key: where to change what

**For almost every case you change only `.env`, no code.** Copy `.env.example` to `.env` and set:

```bash
# Example: OpenAI                      # Example: Groq                        # Example: Google Gemini (OpenAI-compatible endpoint)
LLM_PROVIDER=openai                    LLM_PROVIDER=groq                      LLM_PROVIDER=gemini
LLM_API_KEY=sk-...                     LLM_API_KEY=gsk_...                    LLM_API_KEY=AIza...
ROUTER_MODEL=<small model name>        ROUTER_MODEL=<small model name>        ROUTER_MODEL=<model name>
REASONING_MODEL=<larger model name>    REASONING_MODEL=<larger model name>    REASONING_MODEL=<model name>
```
Use model names exactly as your provider documents them (the defaults `claude-haiku-5-5` / `claude-sonnet-5-5` only work with Anthropic). Restart the app after editing `.env`. The trace panel shows which provider and model answered each call, and falls back to the next provider in `LLM_FALLBACK` (ending in the offline `mock`) if a call fails, so a wrong key shows up as a trace entry rather than a crash.

| If you want to... | Edit this |
|---|---|
| Switch provider / key / models | `.env` only (`LLM_PROVIDER`, `LLM_API_KEY`, `ROUTER_MODEL`, `REASONING_MODEL`) |
| Use a self-hosted or unlisted OpenAI-compatible server (LM Studio, vLLM, a gateway) | `.env`: `LLM_PROVIDER=openai_compat`, `LLM_BASE_URL=http://host:port/v1` |
| Add another preset base URL | `app/config.py`, dict `OPENAI_COMPAT_PRESETS` |
| Fix cost figures for your model | `.env` (`LLM_PRICE_IN/OUT`) or `app/config.py`, dict `MODEL_PRICING` |
| Support a provider with a **non-OpenAI** API (for example a native Gemini or Cohere endpoint) | `app/gateway/llm.py`: add a class with `complete(model, system, user, json_mode, max_tokens) -> (text, tokens_in, tokens_out)` (copy `OpenAICompatProvider`), then register it in `build_provider()` |
| Change what the router or composer is told | `app/gateway/prompts/supervisor_v1.txt`, `compose_v1.txt` (add `_v2.txt` files; the highest version is used) |

Whatever the provider, the gateway masks PII before the request leaves your machine, validates the router's JSON (falling back to deterministic rules), and rejects any composed answer that contains a number not present in the agent-produced draft, so a different model cannot change financial facts. Never commit your real `.env` (it is in `.gitignore`).

---

## 5. Architecture overview mapped to the 9 layers

Diagrams (Mermaid) are in `docs/architecture.md`.

| Layer | Implementation | Files |
|---|---|---|
| 1 Banking channels | One chat UI with persona selector (Customer, RM, Call Center, Fraud Analyst); persona changes permissions, intent policy and data masking | `ui/app.py`, `app/gateway/policy.py` |
| 2 API and experience | FastAPI: `POST /chat`, `GET /customers/{id}`, `GET /trace/{id}`, plus `/auth/login`, `/approve/{trace_id}`, `/audit`, `/metrics`, `/alerts`, `/eval/*`. Pydantic validation, mock bearer sessions, sliding-window rate limit, correlation ID in `X-Trace-ID` | `app/api/` |
| 3 AI gateway / control plane | PII masking, injection/harmful/off-topic guardrails, persona policy, versioned prompt files, router-vs-reasoning model routing, token budget and cost, provider fallback, output safety, audit of every decision | `app/gateway/` |
| 4 Multi-agent orchestrator | LangGraph graph: gateway, route, plan, execute, aggregate. Intent classification with validated JSON, task decomposition, agent selection, shared state, retry then human escalation, result aggregation | `app/agents/supervisor.py` |
| 5 Agent tool / MCP layer | Registry of 12 tools with Pydantic schemas, agent and persona allow-lists, ownership checks, approval gates on writes, timeout sandbox, audit per call; same registry exposed as an MCP server | `app/tools/` |
| 6 Enterprise data | SQLite via SQLAlchemy, deterministic Faker seed: 24 customers, 680 transactions with planted anomalies, loans, credit profiles, KYC | `app/data/` |
| 7 Knowledge / RAG | 5 synthetic policy documents; BM25 plus TF-IDF vector search, Reciprocal Rank Fusion, reranker; every answer cites `[document › section]` | `app/rag/` |
| 8 External services | Mock credit bureau, KYC/AML screening, payment network, market data, with simulated latency and random failures; callers retry | `app/external/` |
| 9 Cross-cutting platform | Trace per request (agent trajectory), audit log table and viewer, FinOps (tokens, cost, latency per agent), reliability (P50/P95, error rate, tool failures), evaluation suite, role-based access, zero-trust re-checks | `app/observability/`, `app/eval/`, dashboard in `ui/app.py` |

### How a chat request flows
1. **API** assigns a trace ID and checks the session token and rate limit.
2. **Gateway node** masks PII, runs guardrails, and (for the Customer channel) blocks any attempt to name another customer.
3. **Route node** asks the router model for intents as JSON (`supervisor_v1.txt`); invalid output falls back to deterministic rules.
4. **Plan node** turns intents into agent tasks, applies persona policy, and orders them (a transfer always gets the fraud risk check first).
5. **Execute node** runs each agent. Agents call tools through the registry, which re-checks permissions every time. Write actions return `pending_approval` instead of executing. A failing agent is retried once, then escalated to a human operator, while other agents' results are kept.
6. **Aggregate node** merges results, asks the reasoning model to rephrase (rejected if it adds any new number), masks any card/SSN leakage, and appends the "Agents: … Tools: …" footer.
7. **Approval**: the UI shows Approve/Reject. `approve()` executes the stored actions with approval, triggers the Notification Agent, and audits the decision. Approvals are bound to the requesting session.

---

## 6. Project structure and file guide

```
banking-agents/
├── app/
│   ├── config.py                 settings from .env (thresholds, models, pricing)
│   ├── service.py                service layer shared by the API and the in-process UI client
│   ├── api/    main.py (routes, middleware) · schemas.py (Pydantic) · security.py (sessions, rate limit)
│   ├── gateway/
│   │   ├── pii.py                regex masking: email, phone, SSN, card, Aadhaar-like, account numbers
│   │   ├── guardrails.py         input guardrails and output content safety
│   │   ├── policy.py             which personas may attempt which intents
│   │   ├── prompts.py + prompts/ versioned prompt files (supervisor_v1.txt, compose_v1.txt)
│   │   ├── budget.py             token estimate, price table, per-request budget
│   │   └── llm.py                provider-agnostic wrapper: anthropic / ollama / mock, fallback chain, usage recording
│   ├── agents/
│   │   ├── supervisor.py         LangGraph orchestrator, HITL approve()
│   │   ├── intents.py            rule-based classifier, RoutingDecision schema, entity extraction
│   │   ├── base.py               Task, RunContext, AgentResult, governed tool-call helper
│   │   ├── customer_agent.py     balances, transactions, transfers
│   │   ├── fraud_agent.py        dispute handling, account review, pre-transfer risk
│   │   ├── credit_agent.py + loan_policy.py   eligibility, EMI, policy RAG, decision rules
│   │   ├── compliance_agent.py   KYC/AML with SOP citations
│   │   ├── product_agent.py      policy / product Q&A from RAG
│   │   └── notification_agent.py simulated SMS / email / push
│   ├── tools/
│   │   ├── registry.py           validation, permissions, ownership, approval, sandbox, audit
│   │   ├── banking_tools.py      the 12 tools and their schemas
│   │   ├── permissions.py        agent and persona allow-lists
│   │   ├── risk.py               fraud scoring: rules plus z-score, and proposed-transfer scoring
│   │   └── mcp_server.py         MCP server over the same registry (SDK v1 and v2)
│   ├── data/   db.py · models.py (15 tables) · seed.py
│   ├── rag/    retriever.py · docs/*.md (loan policy, KYC/AML SOP, fraud SOP, product catalogue, FAQ)
│   ├── external/mock_services.py bureau, KYC, AML, payments, market data
│   ├── observability/ audit.py · trace.py · metrics.py
│   └── eval/   testset.json (19 cases) · runner.py
├── ui/         app.py (layout and logic) · theme.py (design tokens, CSS, icons) · components.py (HTML cards, trace timeline, bank card) · client.py
├── .streamlit/config.toml   Streamlit theme (colours, dark sidebar)
├── scripts/    run_demo.py
├── docs/       architecture.md · demo_script.md · eval_report.md
├── tests/      85 tests across 6 files
├── .env.example · requirements.txt · Makefile · Dockerfile · docker-compose.yml
```

Key behaviours worth knowing when reading the code:
- **Tool pipeline order** (`registry.call_tool`): validate schema → agent allow-list → persona allow-list → customer ownership → approval gate for writes → run in a thread with a timeout → audit. Denials and errors are returned as results, never raised into the agent.
- **Fraud score** (`risk.py`): amount z-score (+30 at z≥3), foreign country (+30), unseen device (+20), velocity of 4+ debits in 15 minutes (+25), foreign login (+15), midnight to 5am (+10), round large amount (+5); HIGH ≥ 70, MEDIUM ≥ 40.
- **Loan decisions** (`loan_policy.py`): thresholds mirror `loan_policy.md` and a test keeps them in sync. EMI always comes from the `calculate_emi` tool. Approvals above `LOAN_HITL_THRESHOLD` pause for an officer.
- **No invented numbers**: figures come from tool output, deterministic agent code over tool data (for example DTI), or retrieved policy text. The evaluation's groundedness metric checks exactly this.

---

### UI design
The interface is a custom design system on top of Streamlit: dark navy sidebar, gradient app bar with session chips, welcome tiles, chat cards with agent/status chips, an approval card, a colour-coded **trace timeline** (guardrail, PII, route, plan, agent, tool, LLM, RAG, approval steps with a latency bar and expandable inputs/outputs), a **Customer 360** view with a bank-card visual that turns red when the card is blocked, and an **operations dashboard** (KPI cards, token and latency charts, tool health with success bars, fraud alert cards, filterable audit log, evaluation results).
- Re-brand: change `BRAND`, `TAGLINE` and the colour tokens in `ui/theme.py`; theme colours also live in `.streamlit/config.toml`.
- Run `streamlit run ui/app.py` **from the project folder** so `.streamlit/config.toml` is applied.
- Fonts load from Google Fonts when online and fall back to system fonts offline.

## 7. Tests and evaluation

```bash
python -m pytest -q                  # 85 tests
python -m app.eval.runner            # 19-case evaluation, writes docs/eval_report.md
```
The evaluation reports routing accuracy, tool-call correctness, answer checks, groundedness, P50/P95 latency, and tokens/cost, per case and overall. It runs on a fresh temporary database each time, so it never changes your demo data. See `docs/eval_report.md` for the latest run.

---

## 8. Troubleshooting

| Symptom | Fix |
|---|---|
| `ModuleNotFoundError: app` when starting Streamlit | run the command from the `banking-agents` folder (the UI also adds the project root to `sys.path`) |
| Demo data looks changed (card blocked, balance lower) | approvals really change the demo database; run `python -m app.data.seed` to reset |
| Occasional "service unavailable" message | intended: the simulated services fail 5% of the time; the system retries once, then escalates. Set `SIM_FAILURE_RATE=0` for a calm demo |
| `pip` fails on `PyJWT` while installing `mcp` (Debian/Ubuntu system Python) | use a virtual environment (Step 1), or `pip install --ignore-installed PyJWT mcp` |
| Real provider returns errors | check `ANTHROPIC_API_KEY` and model names; the trace shows each provider failure and the fallback used |

---

## 9. Known limitations and next steps

**Limitations**
- Everything is simulated; there is no real authentication. Sessions are in-memory tokens, and the persona is chosen by the caller.
- "Embeddings" are sparse TF-IDF vectors in a NumPy index, not a dense neural embedding model, and the reranker is a lexical scorer, not a cross-encoder. FAISS/Chroma were not used. The `TfidfEmbedder` interface (`fit`/`encode`) is where a dense model would plug in.
- Fraud scoring is hand-tuned rules plus a z-score. The brief mentions IsolationForest as an option; it is not used.
- Approvals are bound to the same session that asked (maker and checker are the same person). There is no separate approver role, expiry, or dual control.
- State is in-process: sessions, rate-limit counters and the retriever cache are not shared across multiple API workers. SQLite handles one writer at a time.
- Token counts in `mock` mode are estimates (about 4 characters per token) and cost is zero. Prices in `MODEL_PRICING` are illustrative.
- Prompt-injection and PII detection use regular expressions; they will miss novel phrasings, names and addresses.
- The evaluation set is small and author-written (see section 1). The groundedness metric checks numbers only.
- `python -m app.eval.runner` swaps the global database for a temporary one while it runs; do not chat in another window at the same time.

**Next steps**
1. Replace TF-IDF with a dense embedding model and a cross-encoder reranker; persist the index in Chroma or FAISS.
2. Add IsolationForest (or a learned model) next to the rules, with offline backtesting on the planted anomalies.
3. Real identity (OIDC), a distinct approver role with dual control and expiry, per-persona audit visibility.
4. Run the evaluation against live providers, grow the test set to include adversarial and multi-turn cases, and track results over time.
5. Postgres, a shared rate limiter and trace store, OpenTelemetry export (or LangSmith) for the trajectory view.
6. Multi-turn memory in the supervisor (follow-up questions such as "block it" after a fraud review).
