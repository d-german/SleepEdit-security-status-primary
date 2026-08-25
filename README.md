# SleepEdit Security and Quality Reports

This repository publishes static, detailed transparency reports for SleepEdit's `main` branch and active `feature/*` and `feat/*` branches. GitHub Pages serves the rendered reports from [`index.html`](index.html).

Each report discloses the scanned branch and commit, completed or incomplete scan state, quality-gate result, coverage, dependency findings, test totals, and SonarQube issue and hotspot details. A failed, cancelled, or incomplete scan is shown explicitly and is never presented as passing.

[`trend/index.html`](trend/index.html) records the aggregate security and quality metrics from each completed `main` scan. Snapshots are appended once per commit and contain only bounded counts, ratings, coverage, and dependency totals; they never include source text, issue messages, local paths, credentials, or raw scan artifacts.

Raw scanner JSON, XML, TRX files, source text, credentials, private paths, and private artifact links remain private in the source repository's release evidence. The publishing GitHub App is restricted to this repository and has only metadata-read and contents-write access.
