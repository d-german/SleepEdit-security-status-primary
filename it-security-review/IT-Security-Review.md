# SleepEdit IT & Security Review Guide

Technical, security, privacy, deployment, and data-handling information for healthcare IT reviewers.

**Last reviewed:** August 26, 2026<br>
**Source baseline:** SleepEdit release-candidate commit `446b45a3e86dbf7befedc22209a09f9cf44cba75`<br>
**Application version/framework:** The projects target .NET 10. The repository pins .NET SDK 10.0.301. This review accompanies the planned SleepEdit Desktop 0.1.7 release.

This guide reports what the reviewed source and checked-in configuration establish. It uses four status terms:

- **Confirmed from source** means the reviewed implementation directly supports the statement.
- **Deployment dependent** means the code permits or expects the behavior, but the hosting or customer configuration determines the result.
- **Not implemented** means the reviewed repository contains no implementation of the capability.
- **Requires confirmation** means source code cannot establish the operational, contractual, legal, or organizational fact.

This is technical documentation, not a certification, legal opinion, penetration-test report, or assurance that all identifiers or vulnerabilities will be detected.

## Quick review

| Question | Answer |
|---|---|
| Hosting | The production deployment workflow redeploys a containerized web service on Koyeb. Customer-specific hosting options are not established by source. |
| Framework | ASP.NET Core MVC, Blazor Server, a shared Razor Class Library, and a Windows WPF/Blazor Hybrid host. |
| Current .NET version | .NET 10; SDK 10.0.301 is pinned. |
| PHI persistence | The working note is not written to the application databases. In the web UI it is held in the DOM and `sessionStorage` for up to 30 minutes. Users can still enter PHI, and AI use creates a separate transmission path. |
| AI optional? | Yes. AI settings default to disabled. Deterministic note generation, protocol viewing, medication selection, and local dictation do not require OpenAI. |
| AI provider | OpenAI, through the Responses API at `api.openai.com`. |
| AI pre-screening | Current text, note text, selected protocol values, and history are screened locally. Likely PHI in the current request blocks transmission; likely PHI in prior history causes that history to be omitted. Detection is not guaranteed. |
| Presidio | Not used by the current runtime. Screening and supported screenshot redaction are in-process local operations. |
| Human review required? | Yes. AI suggestions and deterministic documentation remain reviewable content. AI changes require an explicit Apply action; protocol publication is a separate explicit action. |
| API key exposed to browser? | Web: no; the key is read by the server from configuration. Desktop: the key is used by the local process and protected on disk with Windows DPAPI, machine scope. |
| Database contains PHI? | The application does not intentionally store patient notes. LiteDB stores protocols, settings, themes, and medication catalog data. Misuse could still place sensitive text in administrative content. |
| External network dependencies | OpenAI is optional for AI. OpenFDA is optional for drug-label reference. The web UI also needs same-origin HTTPS and WebSocket connectivity to the SleepEdit server. |
| HTTPS | The app redirects to HTTPS and enables HSTS outside Development, but TLS termination and edge-to-container encryption are deployment dependent. The container listens on HTTP port 8000. |
| Authentication | Normal web use has no user authentication. Web administration uses one configured shared password. Desktop administration uses one shared password for the configured content folder. No SSO, MFA, or RBAC is implemented. |
| Admin credential handling | Web: raw configured password remains in process configuration; an ASP.NET password hash is created in memory for comparisons. Desktop: PBKDF2-SHA256, 600,000 iterations, random salt; only salt and hash are stored. |
| Logging | Structured application events and exceptions are logged. Note bodies, AI prompts, AI answers, request bodies, and API keys are not intentionally logged. Some user-controlled names and exception details can appear. Retention and access are deployment dependent. |
| Analytics | No Google Analytics, advertising tracker, third-party product analytics, or crash-reporting SDK was found in the reviewed source. |
| Security scanning | Microsoft security analyzers, .NET tests and coverage, NuGet and npm vulnerability audits, SonarQube Cloud, frontend tests, and a 70% aggregate coverage gate are configured. |
| Public security evidence | Current rendered evidence is published at [security.sleepedit.net](https://security.sleepedit.net/). |
| Support/security contact | The application currently publishes `damon.german@sleepedit.net`. Dedicated `security@` or `support@` aliases are not verified and are not published here. |

## What is SleepEdit, and what is outside its scope?

**Confirmed from source, with regulatory status requiring confirmation.** SleepEdit is documentation and workflow software for sleep disorder centers. It provides a sleep-note editor, deterministic narrative generation from structured selections, protocol guidance, medication reference, local speech-to-text, optional AI assistance, and administration of protocols, themes, medication catalogs, and AI settings.

The application states that it assists documentation and does not diagnose patients or replace clinical judgment. No EHR write-back, autonomous treatment decision, or automatic commitment of generated documentation was found. A user reviews content in the editor and decides whether to copy, print, or otherwise use it.

### Technical detail

Deterministic note generation is implemented as C# rules that convert validated selections into narrative text. The AI assistant is a separate optional workflow. Source code cannot determine whether SleepEdit is legally a medical device; that classification requires owner and regulatory review before publication as a definitive claim.

## Who is the intended user, and what requires human review?

**Confirmed from source.** The UI and documentation identify sleep technicians, clinicians, and authorized administrators as intended users. All clinical content remains subject to qualified human review. AI answers may include a proposed note replacement or protocol change plan, but the user must explicitly apply it.

### Technical detail

For a note proposal, the browser rejects application if the note changed after the proposal was generated. For a protocol plan, the service validates the operation schema, simulates each operation against the draft, and rejects stale plans. Applying a plan changes the draft only; saving and publishing are separate actions. A removal plan also receives an additional browser confirmation.

## Which functions are deterministic, and which are AI-assisted?

**Confirmed from source.** Deterministic functions include structured note generation, medication narrative creation, protocol viewing and checklist composition, local Vosk dictation, protocol editing, and configuration management. AI functions include answering sleep-documentation questions, proposing a replacement for the working note, and proposing bounded protocol-edit operations.

### Technical detail

The deterministic generators do not call OpenAI. Drug-label lookup is an external OpenFDA lookup but is not generative AI. AI settings default to disabled, and missing settings or provider credentials cause AI requests to be unavailable without disabling the deterministic workflows.

## Can SleepEdit operate if AI is disabled or OpenAI is unavailable?

**Confirmed from source.** Yes. The main clinical editor, deterministic generator, protocol viewer, medication catalog, and local dictation continue to work. An unavailable AI request returns a generic temporary-unavailable message and does not apply a change.

### Technical detail

The web application itself still requires connectivity to the SleepEdit server. Desktop deterministic functions can run without public internet if their required local or shared content is available. OpenFDA drug details and OpenAI assistance will not work offline.

## What technologies and application hosts are used?

**Confirmed from source.** SleepEdit has three major layers:

- **Web application:** ASP.NET Core MVC plus interactive Blazor Server components.
- **Desktop application:** a 64-bit Windows WPF shell using Blazor WebView.
- **Shared application logic:** a Razor Class Library containing shared UI, services, domain logic, data access, de-identification, and static assets.

### Technical detail

The web and shared projects target `net10.0`; the desktop targets `net10.0-windows`. The desktop reuses the shared Razor components and services in-process. The web host supplies HTTP controllers, server sessions, security middleware, and web-specific storage paths. The desktop host supplies WPF navigation, machine configuration, local database paths, and Windows secret protection.

## Where does processing occur in web and desktop modes?

**Confirmed from source.** In web mode, the editable note DOM, formatting, local draft, printing, and Vosk audio recognition run in the browser. Blazor Server component events, deterministic C# services, persistence, PHI screening, and external API calls run on the server. In desktop mode, the shared C# services run inside the installed Windows process, while browser-like UI code runs in WebView2.

### Technical detail

Blazor Server uses a same-origin real-time connection, normally WebSockets, for interactive components. This means structured form events can traverse the web connection even though the final free-text working note is deliberately kept in the browser except when the user invokes AI. Desktop Blazor Hybrid does not start an ASP.NET web server in the reviewed code.

## Are high-level architecture diagrams maintained?

**Confirmed from source.** Eight source-maintained PlantUML diagrams are rendered as SVG and published on the [architecture and workflows page](../architecture/). They cover system architecture, sleep-note authoring, medication lookup, protocol viewing, AI assistance, protocol administration, shared settings, and desktop setup.

### Technical detail

The public SVGs are derived artifacts. The editable PlantUML sources live with the application source so changes can be reviewed with the code.

## What is the lifecycle of a working clinical note?

**Confirmed from source.** The working note is created and edited in the browser or desktop WebView. In the web app, it is saved to that tab's `sessionStorage` with a 30-minute application lifetime. It is not written to SleepEdit's LiteDB databases. A browser refresh can restore it while valid; ending the browser tab session normally removes it, although browser session-restore behavior varies.

The note is sent outside this browser-local boundary only when the user explicitly invokes a function that requires it. In the current source, the important exception is AI assistance: the current editor text is sent to the SleepEdit server and, after local screening, may be sent to OpenAI. Printing and copying are explicit user actions controlled by the browser or desktop.

### Technical detail

The storage record contains HTML, selected medication names, and a timestamp. Empty notes are removed. The code has no server endpoint that saves the complete working editor note as a patient record.

## What browser storage, cookies, and caches are used?

**Confirmed from source.** `sessionStorage` stores the working note and AI display conversation, each with a 30-minute application lifetime. `localStorage` stores theme preference, sidebar state, and collapsed protocol-editor section IDs. No IndexedDB use was found.

The web server configures an essential, HttpOnly ASP.NET session cookie. That server session holds the admin-unlocked flag and protocol-editor session state, not the working clinical note. ASP.NET anti-forgery protection can also use framework cookies at runtime. No advertising or analytics cookies were found.

### Technical detail

Server session idle timeout is 30 minutes and the configured backing store is distributed memory, which is process-local in this deployment. Exact cookie names and deployed Secure/SameSite attributes should be verified at runtime because the application does not explicitly set all of them.

## What data is persisted?

**Confirmed from source, with retention deployment dependent.** Persisted application data is administrative and reference data: protocol drafts and versions, published protocols, sleep-note option lists, themes, AI enablement/model policy, medication catalog records, shared-content cache files, desktop machine settings, desktop WebView2 data, and cryptographic key material. The application does not intentionally persist patient notes or AI conversations server-side.

### Technical detail

The web host uses `sleepeditweb.db` and `medications.db`. The desktop uses `sleepedit.db`, `medications.db`, a shared or standalone content folder, `desktop-settings.json`, a WebView2 profile, and local cache files under `%ProgramData%\SleepEdit` by default. Shared published content is JSON. Retention is effectively until changed, deleted, uninstalled, or the deployment storage is replaced; no formal retention schedule is implemented.

## Data flow table

| Information | Created where | Processed where | Persisted where | Sent externally? | Notes |
|---|---|---|---|---|---|
| Generated technical note | Structured form in browser/WebView | Web server for Blazor Server; local process for desktop | Working editor `sessionStorage` only | No, unless AI or user export/copy is invoked | Deterministic rules; no automatic EHR commit |
| User-entered note text | Browser/WebView editor | Browser/WebView normally; server/local process during AI | Browser/WebView `sessionStorage`, up to 30 minutes | OpenAI only after explicit Ask and screening | Not stored in LiteDB |
| Protocol selections | Browser/WebView | Shared protocol services | Selection state is transient; UI collapse state is localStorage | Included in OpenAI context if AI is asked | Published protocol content is administrative, durable data |
| Protocol configuration | Admin editor | Server or desktop process | LiteDB and optionally shared published JSON/cache | Included in AI context for relevant requests | Draft save and publish are separate |
| Admin credentials | Web deployment config or desktop setup | Web server or desktop process | Web raw value in configuration and hash in memory; desktop salt/hash in shared JSON | No | Desktop raw password is not stored |
| OpenAI API key | Hosting secret/config or desktop setup | Web server or desktop process | Web storage is deployment dependent; desktop DPAPI-protected bytes in `desktop-settings.json` | Sent as bearer credential to OpenAI | Never intentionally sent to browser or logged |
| Screenshots/images | Browser/WebView attachment | Server/local process; local OCR/redaction when supported | Not intentionally saved | Redacted PNG may be sent to OpenAI | Current UI enables this only where Windows local redaction is supported |
| Medication reference information | Bundled/administrative catalog | Server or desktop process | `medications.db` | Selected drug name may be sent to OpenFDA | Returned OpenFDA response is transient |
| AI prompts | Browser/WebView | Server/local process and local PHI screen | Browser `sessionStorage` contains display turns; no server prompt store | Sent to OpenAI after gates | Protocol or editor context is included by request type |
| AI responses | OpenAI | Server/local process, then browser/WebView | Browser `sessionStorage` display turns, up to 30 minutes | Received from OpenAI | Schema and semantic validation precede display/application |
| Logs | Server or desktop process | Host logging provider | Host/platform dependent | May be received by hosting log service | No application retention setting |

## Is SleepEdit designed to store PHI, and could PHI still be entered?

**Confirmed from source.** SleepEdit does not intentionally store a patient record or working note in its application databases. It is still a clinical documentation editor, so users can type PHI into the working note, protocol fields, medication names, filenames, or AI prompts. Avoiding intentional database persistence is not the same as proving that PHI can never exist in memory, browser storage, logs, screenshots, clipboard content, print output, or external requests.

### Technical detail

Likely-PHI screening is specific to AI request paths. It is not a general data-loss-prevention layer over every text field, protocol import, administrator field, log placeholder, clipboard operation, or print operation.

## What PHI screening occurs before AI calls?

**Confirmed from source.** Before the main AI answer request, SleepEdit screens current user text using two local layers: bounded regular-expression heuristics and an in-process named-entity recognizer. The recognizer confidence threshold is 0.70. Protected entity categories include people, contact data, government and financial identifiers, locations, URLs, network identifiers, and dates. Known published-protocol text is treated as trusted context to reduce false positives.

Likely PHI in the current question, editor text, or selected values blocks the request before any provider call. Prior conversation history is screened separately; if flagged, it is omitted from the provider request while the user receives a notice. These controls reduce risk but are not foolproof.

### Technical detail

The local heuristic recognizes labeled identifiers, email addresses, telephone/SSN-like values, and patient-related absolute dates. The local NER model adds entity detection. Detection failures fail the AI operation rather than silently bypassing the detector.

## What is Microsoft Presidio used for?

**Not implemented in the current runtime.** The reviewed source makes no runtime Presidio request and registers no Presidio HTTP client. Current text screening uses the bundled `Deidentify` code in-process. Current supported image OCR/redaction also runs in-process.

### Technical detail

Older design documents refer to a Presidio service, but they are not authoritative for the current implementation. A future deployment could add a separately reviewed DLP service, but that is not the behavior documented here.

## What happens when likely PHI is detected?

**Confirmed from source.** If local screening flags the current request, SleepEdit returns a refusal explaining that the request was blocked and was not sent to the AI provider. If only prior history is flagged, the history is removed from the current provider request and processing can continue. If OpenAI's schema-constrained response flags likely PHI, SleepEdit refuses the result and does not offer a proposal.

### Technical detail

Provider-side classification is defense in depth, not a pre-transmission safeguard: the question has already reached OpenAI for the classification call. SleepEdit therefore does not represent its controls as a guarantee that PHI can never reach the provider.

## How are screenshots handled?

**Confirmed from source, with host support limitations.** The UI accepts one PNG no larger than 6 MB, with maximum dimensions of 4096 by 4096 and no more than 12 million pixels. When image support is enabled, OCR and redaction occur locally before the OpenAI answer request. Only the resulting validated PNG is attached. SleepEdit does not intentionally save the original or redacted image.

### Technical detail

The current code advertises image analysis only when running on Windows. That normally makes it a desktop capability, not a feature of the Linux container deployment. The server routes still validate image uploads, so deployment testing should confirm that unsupported hosts cannot expose a misleading image path.

## Which OpenAI API and features are used?

**Confirmed from source.** SleepEdit uses `POST /v1/responses` on `api.openai.com`. Requests set `store:false`, provide a strict JSON schema, set an output-token limit and reasoning effort, and send an empty tools array. No Assistants, Threads, vector stores, Files, web search, or function tools are used by the reviewed code.

### Technical detail

Allowed answer models are currently `gpt-5.6-sol`, `gpt-5.6-terra`, and `gpt-5.6-luna`; the classifier model is `gpt-5.6-luna`. An administrator controls AI enablement, answer model, and maximum reasoning effort. Actual model availability and an organization's approved model list remain deployment/account dependent.

## What information is sent to OpenAI?

**Confirmed from source.** For the sleep-note assistant, the first provider call sends only the current question and whether an image is attached for domain classification. If allowed, the answer call sends the question, current editor text, screened recent history, the published protocol, resolved selected protocol items, and an optional locally redacted image.

For the protocol-editor assistant, the request includes the administrator instruction, screened recent history, selected node ID, the complete current unsaved protocol draft, and an optional locally redacted image. SleepEdit does not retrieve or send an EHR record. It will, however, send whatever clinical text the user has placed in the working editor when the user explicitly asks the assistant.

### Technical detail

At most eight recent history turns are sent, each capped at 2,000 characters. The working note is capped at 40,000 characters. Protocol drafts and provider output have separate size and item limits.

## How are AI responses validated and applied?

**Confirmed from source.** Responses must match a strict JSON schema. Sleep-note answers are checked for required fields, lengths, valid protocol references, and refusal/PHI status. Protocol plans are restricted to nine supported operation kinds, validated for size and references, and simulated against the current draft.

No AI response automatically changes the note, configuration, protocol, or published content. A user must select Apply. A stale note or stale protocol plan is rejected. Saving and publishing protocol changes remain explicit administrative actions.

### Technical detail

Malformed output, invalid references, unavailable provider responses, or failed semantic validation produce a generic unavailable or clarification result. They do not fall back to unvalidated text application.

## Does `store:false` mean zero data retention or no model training?

**Confirmed only as an API request setting.** The code requests `store:false`. The repository contains no evidence that Zero Data Retention or Modified Abuse Monitoring is enabled for the OpenAI organization or project. The code also cannot establish contractual model-training terms.

### Technical detail

Provider retention, abuse monitoring, BAA eligibility, data ownership, and model-training treatment must be confirmed against the specific OpenAI account, project, contract, and current provider documentation. `store:false` alone is not equivalent to a contractual zero-retention guarantee.

## Where is the OpenAI API key stored in web deployments?

**Confirmed from source, protection at rest deployment dependent.** The web server reads `OPENAI_API_KEY` from ASP.NET configuration, normally supplied as an environment variable or hosting secret. The key is attached to server-side outbound requests and is not embedded in JavaScript, rendered into the page, or returned by an endpoint.

### Technical detail

The application does not encrypt or persist the web key itself. Protection at rest depends on the deployment's secret store. The raw value remains available to the application process through configuration. Replacing it normally requires updating the hosting secret/configuration and restarting or redeploying the process. Revocation is performed in the owning OpenAI account.

## Where is the OpenAI API key stored in desktop deployments?

**Confirmed from source.** Desktop setup accepts a locally supplied key. It is encrypted with Windows DPAPI using `DataProtectionScope.LocalMachine`, stored as protected bytes in `%ProgramData%\SleepEdit\desktop-settings.json`, and read by the local SleepEdit process. An environment variable can be used as a fallback.

### Technical detail

Machine-scope DPAPI binds the protected value to Windows rather than to one user account. The installer restricts the machine root, settings, content root, and security directory to read/execute for standard Users while leaving only the state, WebView2, cache, and shared-data directories writable. SYSTEM and local Administrators retain full control. Upgrade/repair reapplies protected-file ACLs. This protects the default local layout from ordinary-user replacement but is not per-user cryptographic isolation.

## Can a customer bring its own OpenAI key, and whose BAA applies?

**Technically confirmed; contractual answer requires confirmation.** Both hosts can use a customer-supplied key: deployment configuration for web, or desktop setup/environment configuration for desktop. Requests are billed and governed by the OpenAI account and project that owns that key.

### Technical detail

Whether a SleepEdit LLC agreement applies to a customer-owned OpenAI account is a contractual question, not something code can decide. A hospital should confirm the account owner, project controls, eligible endpoints/models, retention configuration, and executed agreements before authorizing clinical data.

## How does web administrator authentication work?

**Confirmed from source.** Web administration uses one shared password from the `AdminAccess` configuration section. At startup, ASP.NET's password hasher creates an in-memory hash used for comparison. A successful login writes an unlocked flag to the server session; logout removes it. Admin and Protocol Editor paths are enforced by server middleware, not only hidden in the UI.

### Technical detail

The raw configured password is not written to the application database, but it remains in process configuration. The session idle timeout is 30 minutes. There is no username, role, MFA, SSO, account lockout, failed-attempt counter, login rate limit, or central session-revocation feature. Failed logins and successful unlock/lock events are logged without the submitted password.

## Is there a default web administrator password, and how is it reset?

**No production default is defined in normal application settings.** A fixed credential exists in the checked-in local development launch profile and must not be treated as a production secret. If no web password is configured, web admin login cannot succeed.

### Technical detail

There is no in-application web reset or password-recovery workflow. An operator replaces the deployment configuration value and restarts or redeploys the application. The old password cannot be recovered from SleepEdit; it can only be replaced. Hospitals should ensure production never uses the development launch profile or credential.

## How does desktop administrator authentication work?

**Confirmed from source.** Desktop has one shared administrator password for the configured content folder. It requires at least 12 characters. The raw password is not persisted. SleepEdit stores a 16-byte random salt and a 32-byte PBKDF2-SHA256 hash using 600,000 iterations in `admin-access.json`.

### Technical detail

Unlock state is an in-process Boolean and ends when the desktop process closes. There is no username, role, MFA, lockout, rate limit, or durable login audit. Reset replaces the salt and hash and does not require the old password, but the reset path launches the setup process through Windows UAC and requires local-administrator approval. The installer protects the default local security directory from standard-user writes. A configured external share remains dependent on customer-managed share and NTFS permissions.

## Does SleepEdit support SSO, roles, or enterprise identity?

**Not implemented.** No OIDC, OAuth login, SAML, LDAP, Active Directory, Kerberos, MFA, user directory, or RBAC implementation was found. Normal web use is anonymous; administrative use is controlled by one shared password.

### Technical detail

Enterprise SSO or a reverse-proxy identity layer would be a separate deployment/integration project and must include server-side authorization of every protected route. It should not be represented as current functionality merely because a hosting platform could be placed in front of SleepEdit.

## Which features and endpoints require administrator access?

**Confirmed from source.** Web middleware protects `/Admin` and `/ProtocolEditor`, covering medication administration, theme administration, AI policy, and protocol editing. Destructive Sleep Note configuration operations and medication-catalog removal also require the server-derived administrator session. Anti-forgery validation protects mutation requests. Normal users can view protocols, edit working notes, generate notes, use medications, add shared mask/medication catalog choices in the demonstration workflow, and—if enabled—use AI.

### Technical detail

Shared mask-type, mask-size, and medication additions remain normal technician operations by product decision for the demonstration workflow. Removal and reset operations require the administrator session and anti-forgery validation. Named users, enterprise roles, and hospital identity integration are not implemented.

## Can browser manipulation grant administrator access?

**Confirmed from source.** Merely showing a hidden UI control or changing a client-side route does not set the server session's admin-unlocked value. Web middleware checks the server session for every protected request. A valid stolen session cookie would still be a session-hijacking risk.

### Technical detail

Desktop administration is a local-process boundary rather than a network authorization boundary. It depends on the installed binary, in-process route guard, and filesystem permissions. A user with local code execution or writable shared content is outside the protection expected from a web identity system.

## What network connectivity is required?

**Confirmed from source, exact hostnames deployment dependent.** The web service requires inbound HTTPS from users and same-origin WebSocket connectivity for Blazor Server. The container listens internally on TCP 8000 over HTTP. Optional outbound HTTPS destinations are OpenAI and OpenFDA. The application does not require arbitrary runtime internet access for its deterministic functions.

### Technical detail

Desktop does not configure an inbound listener or localhost service. It may need access to a configured UNC/network share. OpenAI and OpenFDA are contacted directly by the local process in desktop mode. Build and deployment systems have additional dependencies such as NuGet, npm, GitHub, GHCR, Microsoft .NET downloads, model downloads, and Koyeb APIs; those are not application-runtime destinations.

## Network and allowlist table

| Hostname/domain | Direction | Port | Purpose | Required/optional |
|---|---|---:|---|---|
| Customer-approved SleepEdit web hostname, currently `sleepedit.net` | Inbound to web / outbound from browser | 443 | Web UI, MVC, Blazor Server, same-origin WSS | Required for web |
| `api.openai.com` | Outbound from web server or desktop | 443 | Optional AI Responses API | Optional; required only for AI |
| `api.fda.gov` | Outbound from web server or desktop | 443 | Drug-label reference lookup | Optional |
| Configured UNC or shared-content host | Desktop LAN traffic | Deployment specific | Shared protocols, themes, AI policy, and admin credential | Optional; required only for shared desktop content |
| Koyeb control plane | CI/CD outbound | 443 | Production redeploy command | Required for the current deployment workflow, not runtime |
| `ghcr.io` | Koyeb/deployment outbound | 443 | Container image retrieval | Required for the current deployment, not browser use |

## Outbound dependency table

| Service | Purpose | Domain | Protocol | Required/optional | Data sent |
|---|---|---|---|---|---|
| OpenAI | AI classification, answers, and protocol plans | `api.openai.com` | HTTPS | Optional | Question; permitted note/protocol/history context; optional redacted PNG; API credential |
| OpenFDA | Drug-label reference | `api.fda.gov` | HTTPS | Optional | Selected medication name |
| Shared file service | Desktop shared configuration | Customer configured | SMB or customer filesystem protocol | Optional | Published administrative content and desktop admin hash/salt; no intended patient note |

## What happens when a network dependency is blocked?

**Confirmed from source.** OpenAI failure produces a generic temporary-unavailable AI result; deterministic features continue. OpenFDA failure returns a user-facing unable-to-connect or no-result response; medication narrative selection still works. Loss of the web server or its Blazor connection interrupts web interaction. Desktop can continue local deterministic work if its required content is available.

### Technical detail

The OpenAI client has a 10-minute HTTP timeout but no automatic retry policy. OpenFDA tries a brand-name query and then a generic-name query; it has no general retry or circuit breaker. Unsaved browser work is recoverable only from the valid local `sessionStorage` record.

## How is TLS enforced?

**Confirmed in application code; termination details deployment dependent.** The web host processes forwarded headers, redirects HTTP to HTTPS with a 308 outside Development, and enables HSTS outside Development. It also sends a restrictive Content Security Policy plus cross-origin opener/embedder headers.

### Technical detail

The container itself listens on HTTP port 8000, so a reverse proxy such as Koyeb must terminate public TLS. The repository does not prove whether every proxy-to-container hop is encrypted. It also does not prove certificate authority, renewal, cipher policy, or customer-specific TLS inspection behavior.

## What encryption exists at rest?

**Confirmed from source.** LiteDB databases, shared JSON content, local cache files, browser storage, and persisted ASP.NET data-protection key files are not application-level encrypted. Desktop OpenAI key bytes are protected by Windows DPAPI at machine scope. Desktop admin passwords are stored only as salted PBKDF2 hashes. Web secret encryption and volume encryption depend on the hosting platform.

### Technical detail

Because the working note is not intentionally placed in the databases, database encryption does not protect that browser-local note. It remains relevant for administrative content, credentials, logs, browser profiles, and any sensitive data entered contrary to intended use. Backup encryption cannot be claimed because no application backup system is configured.

## Where and how is the public web application deployed?

**Confirmed from checked-in workflow.** A GitHub Actions workflow builds the root Dockerfile, publishes `main` and commit-SHA images to GitHub Container Registry, and requests a Koyeb redeploy of the production `sleepedit` service. The final image uses the .NET 10 ASP.NET runtime, runs as non-root user 1654, and exposes port 8000.

### Technical detail

The build uses Ubuntu 24.04 plus a pinned .NET SDK download and checksum-verified local NER and Vosk model artifacts. The production service's region, instance size, scaling, persistent volume, health check, TLS edge, private networking, and secret-store configuration are not recorded in this repository and require deployment confirmation.

## Are deployments automated, gated, and reversible?

**Confirmed with limitations.** Container publication and Koyeb redeployment are automated on pushes to `main`. Security scanning also runs on pushes and relevant pull requests, but the deployment workflow does not depend on the security-scan workflow. A direct push can therefore deploy before the push scan completes.

### Technical detail

Images are tagged by commit SHA, which gives a technical artifact identifier. No automated rollback workflow, canary deployment, blue/green process, downtime statement, or tested rollback runbook was found. Koyeb and GHCR may provide operational rollback capabilities, but their configuration and testing require confirmation.

## Can SleepEdit be hosted on premises or in a dedicated instance?

**Technically possible, commercially and operationally unconfirmed.** The web app is a containerized ASP.NET Core application with configurable storage paths and environment-based secrets. That makes alternate hosting feasible in principle. The source does not define a supported on-premises product, Helm chart, infrastructure-as-code package, sizing guide, support agreement, or dedicated-instance policy.

### Technical detail

An enterprise deployment would need persistent storage, TLS termination, secret management, identity integration, backups, monitoring, log handling, patching, and an approved network design. None should be assumed from the container alone.

## What is the Windows desktop application?

**Confirmed from source.** SleepEdit Desktop is a WPF shell hosting the same shared Blazor UI and application services through Blazor WebView. It is not a browser pointed at the public SleepEdit server. Clinical services, local PHI screening, deterministic generation, persistence, and optional external API calls execute in the desktop process.

### Technical detail

The current source targets 64-bit Windows and publishes a self-contained .NET `win-x64` payload. It stores the WebView2 profile under `%ProgramData%\SleepEdit\webview2`. Availability of the required Microsoft WebView2 runtime should be validated in the hospital desktop image.

## Can security and architecture evidence be viewed without access to the public website?

**Confirmed from source.** Yes. The desktop release bundles a validated static snapshot of the security report, this IT review, architecture/workflow diagrams, and trend page. The About page opens those files inside the local WPF/Blazor shell, so viewing the evidence does not require access to `security.sleepedit.net`.

### Technical detail

The snapshot is copied from an explicit public-file allowlist, records its source commit in `snapshot.json`, and is validated before installer packaging. This makes the evidence pages local; it does not make optional OpenAI or OpenFDA requests network-free.

## How is desktop software installed and updated?

**Confirmed from source.** The installer is a per-machine, x64 MSI built with WiX 3.14.1. Application files install under 64-bit Program Files. Machine data defaults to `%ProgramData%\SleepEdit`. Initial setup requests elevation and can configure a local or UNC shared-content path, an admin password, AI policy, and a local API key.

### Technical detail

The MSI supports major upgrades and blocks downgrades. New tagged releases can publish an MSI to GitHub Releases. No automatic updater is implemented; a new MSI must be deployed. No Authenticode/code-signing step is present in the build workflow, so signing status must not be assumed.

## What does uninstall remove?

**Confirmed from installer configuration.** Uninstall removes the application, shortcuts, legacy registry key, and the complete local `%ProgramData%\SleepEdit` tree, including local databases, caches, WebView2 data, standalone content, and the protected local API-key copy. It does not delete an external configured network share.

### Technical detail

This behavior is destructive for local configuration and should be incorporated into endpoint-management backup and redeployment procedures. A repair or upgrade is designed to preserve machine configuration and data.

## How are protocols created, stored, and published?

**Confirmed from source.** Administrators can create named protocols, load them into an editor, modify a durable draft, save, import/export, and explicitly publish. Web data is stored in LiteDB; desktop can also publish a JSON snapshot to a configured shared content folder. Normal protocol viewing is read-only.

### Technical detail

The repository maintains a workspace draft and published snapshot, named protocols, current-protocol records, and timestamped protocol versions. Shared publication uses an atomic temporary-file-and-move operation and refreshes a local cache. Browser developer tools cannot publish a web protocol without both a valid admin server session and anti-forgery token, although a user who controls the underlying data files is outside that boundary.

## Are protocol changes automatically active?

**Confirmed from source.** No. Editing changes the in-memory/session draft. Save persists a draft. Publish is a separate explicit action that updates the published record and, when configured, the shared published JSON file. AI-assisted operations first require Apply and still require the ordinary save/publish actions.

### Technical detail

The source records timestamps and versions but has no user identity model. It can list stored versions internally, but a complete, documented user-facing restore workflow for every historical version was not confirmed. Shared publication overwrites the current shared JSON snapshot.

## Can protocol or configuration changes be audited?

**Not comprehensively.** Protocol versions and workspace timestamps provide change history, and application logs record operation types, IDs, sources, and counts. They do not identify a human user because administration uses a shared password. There is no tamper-resistant audit ledger.

### Technical detail

Anyone with direct database or shared-folder access can alter or delete the underlying records. Theme, AI-policy, medication, and protocol changes are not represented as a unified audit stream. Hospitals requiring attributable audit history need an additional control.

## What databases exist, and do they contain patient data?

**Confirmed from source.** SleepEdit uses embedded LiteDB files. `sleepeditweb.db` or desktop `sleepedit.db` contains application configuration, protocol data, themes, and AI settings. `medications.db` contains built-in and user-added medication catalog records and seed metadata. The schema does not intentionally include patient records or working clinical notes.

### Technical detail

Medication databases are writable, not immutable bundled references. Administrators can import, replace, reseed, rename, remove, and export catalog data; the normal medication tool also supports approved catalog maintenance paths. The database files are not application-level encrypted.

## What writable state survives a restart or deployment?

**Confirmed from source; web durability deployment dependent.** LiteDB files, shared JSON, desktop machine settings, and cache files survive process restart when their filesystem storage survives. Browser `localStorage` survives browser restarts; `sessionStorage` has tab-session semantics and a 30-minute application expiry. In-memory web sessions do not survive a process restart.

### Technical detail

The Linux default data path is `/app/Data`. A persistent Koyeb volume or equivalent durable mount is required for data to survive container replacement. Whether the current production service has that mount is not proven by this repository.

## What does SleepEdit log?

**Confirmed from source.** SleepEdit logs endpoint and service lifecycle events, validation outcomes, operation counts, model names, token counts, protocol IDs, selected medication/drug names for lookup, admin unlock/lock outcomes, and exceptions. Default application level is Information and ASP.NET Core level is Warning.

It does not intentionally log raw request bodies, complete notes, AI questions, AI answers, screenshots, passwords, API keys, authorization headers, cookies, or OpenAI payloads. This is an implementation policy, not a technical guarantee that PHI can never enter a log.

### Technical detail

Some logged fields are user controlled, including drug names, protocol names, filenames, and paths. Exceptions may include operational details. There is no centralized redaction processor. Destination, access control, export, integrity, and retention are supplied by the host's logging configuration and are not defined by SleepEdit.

## Are authentication failures and administrator actions logged?

**Partially.** Web incorrect-password attempts, successful unlocks, and logout events are logged. Many protocol and settings operations are logged by action and object ID. Desktop password attempts and password resets are not a durable, attributable audit trail.

### Technical detail

Logs do not contain a username because no individual user identity exists. They should not be represented as a HIPAA audit log or as sufficient nonrepudiation evidence.

## Are exception details shown to users?

**Confirmed from source.** In non-Development environments, ASP.NET uses a general error handler and HSTS. AI and several service failures return generic user messages. Development behavior can expose more diagnostic detail and must not be used for production.

### Technical detail

The application logs exception objects server-side. The exact hosting log viewer and who can access it require deployment confirmation.

## What automated security and quality controls run in CI?

**Confirmed from checked-in workflow.** The security workflow runs Microsoft .NET security analyzers, a release build, .NET tests with OpenCover coverage, direct and transitive NuGet vulnerability review, npm audit with failure on high or critical findings, first-party frontend unit coverage, SonarQube Cloud analysis, a Sonar quality gate, a checked-in finding baseline, and a 70% aggregate coverage minimum.

### Technical detail

The workflow runs on pull requests to `main` or `develop`, pushes to `main`, and manual dispatch. Evidence artifacts are retained by GitHub Actions for 90 days and a sanitized report is published at [security.sleepedit.net](https://security.sleepedit.net/). Current public ratings should be read from that live report rather than copied into this guide.

## Are browser tests performed?

**Confirmed in the repository, not confirmed as a required CI gate.** The repository contains Playwright tests for clinical workflows, privacy boundaries, CSP, administration, protocol editing, mobile layouts, and accessibility-related interactions. The current security and frontend workflows do not run the Playwright suite.

### Technical detail

Unit and component tests run in the security workflow. A hospital should not infer continuous rendered-browser regression coverage merely from the presence of Playwright tests.

## Are CodeQL, Dependabot, secret scanning, DAST, or penetration testing used?

**Not established by the reviewed repository.** No CodeQL workflow, Dependabot configuration file, DAST workflow, penetration-test report, or formal secret-scanning workflow was found. SonarQube performs static analysis and basic secrets analysis, while NuGet and npm audits check known vulnerable dependencies.

### Technical detail

Repository-host settings can enable Dependabot or GitHub secret scanning without a checked-in file, so those require GitHub administration confirmation. No penetration test should be claimed without a dated report and scope. The existing security documentation explicitly describes OWASP ZAP as a future recommended layer, not a completed control.

## How are third-party dependencies managed?

**Confirmed from source.** Direct NuGet versions are explicit in project files. npm installs are locked by `package-lock.json` in CI. GitHub Actions in the main security and release workflows are mostly pinned to commits. NuGet direct/transitive vulnerability checks and npm audit run automatically.

### Technical detail

Major runtime dependencies include ASP.NET Core, Blazor WebView WPF, LiteDB, ONNX Runtime, Microsoft tokenizers, SkiaSharp, Tesseract, Vosk, Bootstrap, and limited browser libraries. This guide intentionally does not reproduce the full package list.

## Is an SBOM generated, and are licenses tracked?

**Not implemented.** No CycloneDX, SPDX, Syft, or other SBOM generation was found. The repository contains some third-party license files, but no complete automated license inventory or policy gate was found.

### Technical detail

An SBOM can technically be generated from the project, package-lock, restore graph, container, and MSI, but “available on request” is a commercial commitment that requires confirmation. An SBOM should be produced and archived per release before making that promise.

## Are build artifacts signed or reproducible?

**Partially confirmed.** Container builds pin and checksum major downloaded SDK/model inputs and tag images by source SHA. Desktop releases are built from a tagged or manually supplied version. No container signature, provenance attestation, MSI Authenticode signing, deterministic-build attestation, or reproducibility verification was found.

### Technical detail

The repository uses exact direct package versions, but restore can still depend on external feeds and transitive resolution. Hospitals should request a release-specific hash, SBOM, scan evidence, and signed artifact when those controls are implemented.

## What needs backup?

**Confirmed from source; backup policy not implemented.** Because SleepEdit does not intentionally persist the working patient note, application backups primarily protect protocols, shared published content, themes, AI policy, sleep-note option lists, medication catalogs, desktop machine settings, and cryptographic keys. Browser working notes are not centrally backed up.

### Technical detail

Medication data can be exported as JSON. Protocols can be exported as JSON or XML through the relevant UI. LiteDB and shared-content files can be copied with an application-consistent procedure. No scheduled backup job, retention schedule, off-site copy, restore test, or backup encryption control is included.

## What are the disaster-recovery commitments?

**Requires confirmation.** No formal RPO, RTO, high-availability design, disaster-recovery plan, hosting-provider failure procedure, or tested restore runbook was found.

### Technical detail

A technical restore would require a known-good application image or MSI, durable data and shared-content backups, deployment configuration, cryptographic keys, and current secrets. Source control and container registries help reconstruct software but are not substitutes for customer-data/configuration backup.

## What happens during common failures?

**Confirmed from source, operational recovery deployment dependent.** OpenAI and OpenFDA failures degrade only their optional features. A web-server or Blazor connection failure interrupts interactive web work. The local 30-minute working-note record can restore a recent note in the same browser tab context. Desktop local deterministic work can continue without the public web service.

### Technical detail

There is no application-wide offline synchronization, queued retry, multi-region failover, or conflict resolution. If a web process restarts, admin and protocol editor sessions are lost. If container storage is ephemeral, durable application configuration can also be lost.

## What data is retained and how is it deleted?

**Confirmed from source; formal policy absent.** Working notes and AI display history have a 30-minute browser-storage lifetime and can be cleared by the user. The application does not retain AI conversations server-side. Administrative databases and files remain until an administrator changes/deletes them, storage is removed, or desktop uninstall deletes local data.

### Technical detail

Logs and backups have no application-defined retention. OpenAI retention beyond `store:false` is not established. There is no patient-record deletion API because no patient-record data model exists. There is also no comprehensive “delete every trace” workflow for browser caches, host logs, print queues, clipboard content, or provider-side records.

## Does SleepEdit collect analytics, telemetry, or crash reports?

**Confirmed from reviewed source.** No Google Analytics, tag manager, advertising tracker, third-party product analytics, Application Insights, Sentry, or external crash-reporting SDK was found. .NET CLI telemetry is disabled during the container build.

### Technical detail

Ordinary server/desktop logs still record usage and failures, and hosting infrastructure can collect network and platform telemetry. Those platform controls and retention are deployment dependent.

## Does SleepEdit use tracking cookies or pixels?

**Confirmed from reviewed source.** No advertising cookie, tracking pixel, third-party tracker, or analytics consent framework was found. The application uses an essential server session and framework anti-forgery mechanisms.

### Technical detail

Whether a consent banner is legally required depends on the deployed cookies, jurisdiction, organization policy, and any infrastructure added outside this code. The current source alone does not create a marketing-cookie consent requirement.

## What privacy statement exists?

**A complete privacy statement is not implemented.** The current `/Privacy` page is a placeholder. The About page describes technical data handling and safety boundaries but is not a comprehensive privacy notice.

### Technical detail

Questions about personal-information collection, sale, advertising use, ownership, customer reuse, data-subject rights, and contractual deletion are legal/organizational commitments and cannot be answered from code. The technical implementation has no advertising or cross-customer patient-data store, but that does not replace a published privacy policy.

## Is SleepEdit HIPAA compliant or certified?

**No such claim is made.** Source code cannot establish HIPAA compliance, certification, Covered Entity status, or Business Associate status. HIPAA has no general software “certification” that this guide can confer. Technical safeguards are only part of a hospital's administrative, physical, contractual, and risk-management evaluation.

### Technical detail

The deterministic workflow does not require SleepEdit to retain a patient record, but users can enter PHI. AI screening is risk reduction, not guaranteed de-identification. A BAA does not by itself make software, a vendor, or a deployment HIPAA compliant.

## What is the OpenAI BAA status?

**Requires owner confirmation before publication as a contractual fact.** The private repository contains a draft BAA request and questions for OpenAI, but no executed agreement or account-level retention approval. This guide therefore does not state that a BAA exists.

### Technical detail

If an agreement is executed, the hospital must still confirm the covered OpenAI organization/project, permitted API, models, retention settings, customer-key boundary, incident terms, and the complete SleepEdit deployment. Contract execution would not change the code's local screening, `store:false`, or human-review requirements by itself.

## Which external service providers are involved?

**Confirmed technically; legal roles require confirmation.** The current deployment uses Koyeb for the web runtime and GitHub/GHCR for source workflows and container distribution. OpenAI is an optional runtime AI provider. OpenFDA is an optional public drug-label data source. GitHub Pages hosts the public security-evidence site.

### Technical detail

This guide does not label any provider a HIPAA subprocessor. That characterization depends on contracts, service configuration, and whether PHI is permitted or received.

| Service | Purpose | Data potentially received | Required/optional |
|---|---|---|---|
| Koyeb | Current production web hosting | Application traffic and host logs/metrics; exact visibility depends on TLS and logging configuration | Required for current public web deployment |
| OpenAI | AI classification, answers, and protocol plans | Screened request context and optional redacted image | Optional |
| OpenFDA | Public drug-label lookup | Medication name | Optional |
| GitHub / GHCR | Source automation, security evidence, releases, container images | Source/build metadata; not intended clinical runtime data | Required for current delivery process |
| GitHub Pages | Public security documentation | Reviewer browser request metadata | Optional to clinical operation |

## Is there a formal incident-response process?

**Not established by the repository.** No formal incident-response plan, severity matrix, notification timeline, evidence-preservation procedure, or customer-notification playbook was found.

### Technical detail

The application publishes `damon.german@sleepedit.net` as its current general contact. Dedicated security and support aliases are not verified. Hospitals should require a documented reporting channel, responsible roles, notification terms, and escalation process before production approval.

## Is there a vulnerability-disclosure program?

**Not implemented.** No `security.txt`, SECURITY.md, coordinated-disclosure policy, or bug-bounty program was found. This guide does not imply a bug bounty exists.

### Technical detail

A simple policy should define the reporting address, safe-harbor expectations, supported versions, encryption option, acknowledgment target, remediation communication, and exclusions. The address must be configured and owner-approved before publication.

## How are updates and security patches managed?

**Partially confirmed; service levels require confirmation.** Source changes are tracked in Git. Main-branch container images are built and redeployed automatically. Desktop updates require building and installing a new MSI. Dependency audits and analyzers identify many update needs.

### Technical detail

.NET 10 is the current target. Whether it is an LTS release and the organization's patch window should be confirmed against the current Microsoft lifecycle at review time. No committed patch SLA, emergency-release process, supported-version policy, or desktop auto-update mechanism was found.

## How is change management enforced?

**Partially confirmed.** GitHub workflows support pull-request scanning and record production image source SHAs. Security and quality evidence is published for `main`. The repository does not itself prove that branch protection requires pull requests or successful checks, and the deployment workflow can run independently of the security workflow.

### Technical detail

Installer releases create GitHub release entries with source SHA information. No formal release-note standard, approval matrix, segregation-of-duties policy, or customer change-notification process was found.

## What browsers and accessibility standards are supported?

**Requires confirmation.** No formal browser/OS support matrix, minimum screen resolution, WCAG conformance statement, VPAT, or independent accessibility audit was found.

### Technical detail

The web app requires JavaScript, modern ES modules, WebSockets/SignalR, WebAssembly for local Vosk dictation, AudioWorklet and microphone permission for dictation, browser storage, and contenteditable support. Source includes ARIA labels, keyboard behaviors, responsive layouts, component tests, and Playwright interaction tests, but these are not equivalent to formal conformance.

## Does SleepEdit integrate with Epic, an EHR, HL7, or FHIR?

**Not implemented.** No Epic, EHR, HL7, FHIR, SMART on FHIR, hospital database, domain credential, or direct chart-write integration was found. SleepEdit does not automatically commit generated text to an EHR.

### Technical detail

The technologist can review and then copy, print, or otherwise transfer text through ordinary user action. Any future EHR integration would introduce new authentication, authorization, audit, data-flow, interface-engine, availability, and vendor-contract review requirements.

## What hospital privileges does installation require?

**Confirmed from source.** The web application requires no local workstation installation, but users need browser access to the approved URL and WebSockets. The desktop MSI is per-machine and initial setup requests administrator elevation. Normal desktop use is not coded to require elevation.

### Technical detail

Desktop setup writes Program Files and ProgramData, can access a UNC share, and can store a machine-scoped API key. Endpoint-management packaging, EDR compatibility, allowlisting, WebView2 runtime, code signing, and share permissions require hospital validation.

## Who owns data entered into SleepEdit?

**Requires contractual confirmation.** The source contains no customer-data ownership clause, license grant for clinical content, OpenAI ownership term, or promise about reuse. It therefore cannot answer who legally owns hospital-entered content.

### Technical detail

Technically, SleepEdit does not maintain a cross-customer patient-content database or reuse stored notes for another tenant. OpenAI receives data only on explicit AI requests. Legal ownership, provider rights, training terms, and customer export/deletion rights must be documented separately.

## Is the current application multi-tenant?

**Not implemented as a tenant-aware system.** No tenant identifier, organization-scoped authorization, per-tenant database partition, or customer-isolation layer was found. A web deployment is one application instance with shared configuration and one shared admin password.

### Technical detail

Customer isolation would therefore depend on deploying separate instances and storage, or on implementing a reviewed tenant and identity model. A dedicated-instance commitment is commercial and operational, not established by source.

## What supports business continuity and portability?

**Confirmed technically, commitments unknown.** Deterministic functionality does not depend on OpenAI. Protocols can be represented as JSON or XML, medication data can be exported as JSON, and the application is built on common .NET/container/Windows technologies. This reduces some technical lock-in.

### Technical detail

There is no source-escrow agreement, cessation plan, customer-run license, guaranteed export service, or documented transition assistance. The ability to reconstruct and operate the product after vendor cessation is a commercial/legal question.

## Is SleepEdit open source?

**Requires owner confirmation; no open-source grant was found.** The root repository has no public open-source license file. The application identifies SLEEPEDIT LLC as developer/licensor and displays an all-rights-reserved notice. Third-party components retain their own licenses.

### Technical detail

Without an explicit license, public source availability alone would not grant open-source rights. Customer source access, escrow, audit rights, and proprietary component boundaries require a contract or published licensing policy.

## AI request sequence for architecture review

**Confirmed from source.** The following is the accurate high-level sequence. “Likely PHI” is not a successful return value that continues into an answer; it is a blocking or history-removal decision.

### Technical detail

```text
User selects Ask
  -> validate size, shape, and current editor/draft revision
  -> locally screen current question + editor/draft + selected values
       -> likely PHI: block; do not call OpenAI
  -> locally screen prior conversation
       -> likely PHI in history: omit history and continue with notice
  -> sleep-note path only: OpenAI domain classification of question
       -> off topic or provider refusal: return refusal; no answer request
       -> provider flags likely PHI: return refusal; question was already sent
  -> locally OCR/redact optional image when supported
       -> failure: stop; do not send image or answer request
  -> OpenAI Responses API request with store:false, no tools, strict schema
  -> parse schema and validate lengths, references, status, and operations
       -> invalid: return generic unavailable/clarification; do not apply
  -> show answer and optional proposal to the user
  -> optional explicit Apply
       -> stale or semantically invalid: reject
       -> valid: update working note or protocol draft only
  -> separate explicit Save/Publish for protocol administration
```

## Additional hospital review questions

The following questions are commonly raised during enterprise reviews and are not fully covered by a standard product questionnaire.

## In which geographic region is application data processed?

**Requires deployment confirmation.** The source identifies Koyeb as the current host but does not declare the production region, data-residency commitment, log region, backup region, or OpenAI project processing controls.

### Technical detail

Region and cross-border-transfer review must cover the selected Koyeb service, any volume and log service, OpenAI account/project, OpenFDA request metadata, GitHub delivery systems, and hospital endpoints.

## Is high availability configured?

**Requires deployment confirmation.** No multi-instance, multi-zone, or multi-region topology is defined in source.

### Technical detail

The use of process-local sessions and writable LiteDB files also means scaling to multiple web instances requires an explicit session, database, and file-consistency design.

## What health checks and monitoring exist?

**Not implemented as an application contract.** No dedicated readiness or liveness endpoint, synthetic monitor, alert route, on-call policy, or service-level dashboard was found.

### Technical detail

Koyeb may provide platform health checks and metrics, but their current configuration and alert recipients require confirmation.

## What capacity and performance limits are documented?

**Requires confirmation.** No hospital sizing guide, concurrency test, load-test report, maximum-user statement, or performance SLO was found.

### Technical detail

Relevant limits include Blazor Server circuit memory, OpenAI request duration, process-local sessions, LiteDB write concurrency, WebSocket count, and the configured Koyeb instance size.

## Can the web app run behind a hospital reverse proxy or web application firewall?

**Technically possible, not certified.** ASP.NET processes forwarded host, scheme, and client-IP headers. No tested WAF or reverse-proxy configuration is supplied.

### Technical detail

The proxy must support WebSockets, preserve anti-forgery/session cookies, set trusted forwarded headers, enforce the approved host, and avoid buffering or inspecting clinical content contrary to policy.

## Does SleepEdit support an outbound HTTP proxy?

**Not explicitly configured.** The application uses standard .NET `HttpClient`, but no application option for proxy URL, proxy credentials, PAC files, or no-proxy rules was found.

### Technical detail

Operating-system or container-level proxy behavior may work, but OpenAI and OpenFDA flows must be tested without exposing credentials in proxy logs.

## Does SleepEdit use mutual TLS or certificate pinning?

**Not implemented.** Outbound clients use ordinary platform HTTPS validation. No client certificate, private CA bundle, certificate pin, or mTLS option was found.

### Technical detail

TLS inspection and private trust roots are deployment concerns. Any interception should be reviewed for handling of AI payloads and API credentials.

## Is IPv6 required or explicitly supported?

**Requires runtime confirmation.** No IPv6-specific listener, firewall, allowlist, or test configuration was found.

### Technical detail

The container binds through ASP.NET's generic HTTP URL and external DNS/provider networking determines address families.

## Does the container run with least privilege?

**Confirmed in the image, broader controls deployment dependent.** The final container runs as non-root user 1654. It needs write access to its data and data-protection-key paths.

### Technical detail

No read-only root filesystem, dropped Linux capabilities, seccomp profile, network policy, or Kubernetes security context is defined because no Kubernetes manifest is supplied.

## Does the desktop app install or run a Windows service?

**Not implemented.** The reviewed MSI installs an interactive WPF application and shortcuts. It does not create a Windows service, scheduled task, local web server, or background agent.

### Technical detail

Initial setup elevates through `runas`; normal application startup runs in the interactive user's context.

## Can multiple web instances safely share the current data store?

**Not established.** The current design uses local LiteDB files and in-memory sessions. No distributed locking, shared session store, or multi-writer topology is configured.

### Technical detail

Horizontal scaling requires a reviewed persistence and session redesign or a strictly single-writer/shared-filesystem design supported by LiteDB and the hosting platform.

## What input and upload limits reduce denial-of-service risk?

**Partially confirmed.** AI text, history, draft, output, operation count, and image dimensions/bytes are bounded. AI endpoints are limited to 10 requests per minute per observed remote IP with no queue. Protocol and medication imports perform format validation.

### Technical detail

There is no general application-wide request-rate policy, admin-login rate limit, account lockout, per-session quota, or documented upstream WAF limit.

## How are cross-site request forgery and script injection addressed?

**Confirmed from source.** State-changing web controllers use ASP.NET anti-forgery validation. The site sends a CSP, avoids source-authored inline scripts/styles, renders AI display text with safe DOM text operations, and sanitizes persisted medication names.

### Technical detail

The CSP is an important mitigation, not a complete injection proof. Uploaded protocol and administrative data still require server validation, which the reviewed services provide for their supported schemas.

## What security headers are set?

**Confirmed from source.** SleepEdit sets CSP, Cross-Origin-Opener-Policy, Cross-Origin-Embedder-Policy, HSTS outside Development, and same-origin resource policy for static files.

### Technical detail

No explicit Referrer-Policy, Permissions-Policy, or X-Content-Type-Options header was found. The CSP allows `ws:` and `wss:` schemes broadly for connectivity; tightening and runtime header verification are recommended.

## Is dictation audio sent over the network?

**Confirmed from source.** Vosk speech recognition runs in the browser or desktop WebView using a model served with the application. Audio and recognition hypotheses are not intentionally submitted to a SleepEdit HTTP endpoint or external speech provider.

### Technical detail

The browser microphone and Web Audio pipeline still hold audio in device memory. Browser extensions, endpoint capture tools, or compromised clients are outside the application guarantee.

## How is the local speech and NER model supply chain controlled?

**Partially confirmed.** The container build downloads the .NET SDK, NER model, and Vosk model from fixed URLs and verifies SHA-256 checksums before packaging. Desktop builds use repository/package inputs.

### Technical detail

No signed model manifest, model SBOM, recurring model vulnerability review, or independent provenance attestation was found.

## Are temporary files used for sensitive requests?

**Confirmed from source.** AI image uploads are read from request streams into bounded memory. OpenAI payloads are built in memory. The current AI paths do not intentionally write prompt, response, or screenshot temporary files.

### Technical detail

Hosting frameworks, reverse proxies, crash dumps, swap, EDR products, and OS diagnostics can create copies outside application control and must be covered by deployment policy.

## Can process dumps or swap contain sensitive text or API keys?

**Yes, potentially.** The server/desktop process temporarily holds editor text used for AI, redacted image bytes, provider responses, and the API key in memory.

### Technical detail

SleepEdit does not configure dump encryption, swap encryption, dump collection, or memory-scrubbing guarantees. Hospital endpoint and hosting policies must restrict dump generation and access.

## Are timestamps and time zones handled consistently?

**Partially confirmed.** Protocol, settings, medication, and report timestamps are generally recorded in UTC. UI display and host clocks remain environment dependent.

### Technical detail

No NTP enforcement or clock-skew monitoring is included. Audit-quality timelines require trusted host time and explicit display-zone handling.

## Is localization supported?

**Not established.** UI text and generated clinical prose are English, and the installer language is 1033 (English, United States). No localization resource strategy or translated clinical-content validation was found.

### Technical detail

Numeric formatting is explicitly invariant in some narrative paths, but locale and accessibility testing outside English require separate review.

## Does SLEEPEDIT LLC have remote access to a hospital deployment?

**Requires confirmation.** No remote-support agent, backdoor, vendor account, or remote-control feature was found in the application.

### Technical detail

Any support VPN, hosting-console access, endpoint-management channel, or hospital-approved screen sharing would exist outside this code and must be documented contractually and operationally.

## Is the desktop app compatible with EDR and application control?

**Requires hospital testing.** The desktop includes a self-contained .NET runtime, WebView2 UI, ONNX inference, Tesseract OCR, SkiaSharp, local databases, WebAssembly assets, and optional outbound HTTPS.

### Technical detail

Unsigned MSI status, the intentionally writable runtime-data subdirectories, model files, DLL loading, and WebView2 subprocesses are likely application-control review points. No vendor-specific EDR certification was found.

## How is configuration drift detected?

**Not implemented comprehensively.** Shared files include schema versions and timestamps, and security baselines are version controlled. There is no desired-state inventory or alert when production secrets, storage mounts, Koyeb region, proxy rules, or shared-folder ACLs drift.

### Technical detail

An enterprise deployment should export a sanitized configuration inventory and compare it during release and operational reviews.

## Is key rotation automated?

**Not implemented.** OpenAI keys can be replaced by changing web configuration or rerunning desktop setup, and compromised keys can be revoked at OpenAI. There is no scheduled rotation, dual-key rollover, age alert, or key inventory.

### Technical detail

Web rotation normally requires restart/redeploy. Desktop rotation replaces the machine-protected value. Operational procedures should verify the old key is revoked and absent from backups/logs.

## What happens if a LiteDB file is corrupt?

**Partially handled.** Some repositories fall back to defaults, embedded content, shared published content, or local cache and log the failure. The application does not provide a comprehensive database repair workflow.

### Technical detail

Recovery depends on a valid export or file backup. Corruption tests and restore instructions should be included in a disaster-recovery runbook.

## How are concurrent administrator edits handled?

**Limited controls are confirmed.** Individual web protocol-editor sessions have their own snapshot and stale AI-plan checks. The source does not implement general optimistic concurrency tokens, named-user locks, or merge conflict resolution for multiple administrators.

### Technical detail

Last-writer behavior and LiteDB serialization can lead to overwritten administrative changes. Hospitals should restrict concurrent administration or require a concurrency enhancement.

## What happens if the browser closes unexpectedly?

**Confirmed with browser-dependent limits.** A recent working note and AI display conversation may be restored from that tab's `sessionStorage` for up to 30 minutes. Browsers normally clear session storage when the tab session ends, but crash and session-restore behavior differs.

### Technical detail

There is no server draft recovery for the working clinical note. Users should transfer approved output to the system of record before closing when continuity is required.

## Can clipboard and print workflows create PHI copies?

**Yes.** Copying or printing is an explicit user action and can move clinical text into the operating-system clipboard, print spooler, PDF printer, or destination application.

### Technical detail

SleepEdit does not control clipboard history, printer retention, virtual-print destinations, DLP agents, or the target EHR. Hospital endpoint controls remain necessary.

## Can all active admin sessions be revoked immediately?

**Not implemented.** A web user can log out their session. Restarting the process clears in-memory sessions. There is no administrative view or global revocation command.

### Technical detail

Changing the password does not directly enumerate or invalidate already-unlocked sessions. Enterprise identity integration should provide central session and credential revocation.

## Is a threat model maintained?

**Not confirmed as a current formal artifact.** The repository contains security design documents, diagrams, tests, and findings baselines, but no single current threat model with assets, trust boundaries, abuse cases, owners, and review date was found.

### Technical detail

The architecture diagrams and this guide provide inputs for a threat model. A formal review should cover anonymous web access, AI data flow, desktop local-user boundaries, shared folders, LiteDB, deployment automation, and third parties.

## What evidence should a hospital request for the exact release?

**Recommended review package.** Request the source commit and image/MSI hash, current public scan report, full private scanner evidence under NDA as appropriate, dependency reports, SBOM when available, penetration-test scope/report when completed, deployment configuration inventory, executed agreements, backup/restore evidence, incident-response contacts, and a completed gaps remediation status.

### Technical detail

Evidence should identify the exact deployed source SHA. A generic report or a scan of a different branch is not proof for the production release.
