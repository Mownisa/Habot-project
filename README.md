# ☁️ HabotConnect Hiring Project — Junior Cloud & DevOps Engineer

👋 **Candidate:** Mownisa
📧 **Contact:** vmownisa@gmail.com
🎯 **Role:** Junior Cloud & DevOps Engineer (GCP / Django / React)
🏢 **Company:** HabotConnect FZCO

---

## 📖 About this project

This repo is my submission for HabotConnect's Hiring Project Form — a simulation of a "worst day" staging incident where secrets leaked into raw code and a schema mismatch broke downstream analytics. The three tasks below restore system integrity, following HabotConnect's "Golden Rules" of zero deviation and zero reliance on human judgment.

---

## 🗂️ What's in this repo

### 🏗️ `terraform/` — Secure Staging Infrastructure (Task 1)
- 🪣 **D0 Raw Landing** — a GCS bucket for unvalidated incoming data, versioned, lifecycle-limited to 30 days, uniform bucket-level access, public access blocked
- 📊 **D1 Staged/Enforced** — a BigQuery dataset for validated data only, explicit least-privilege IAM (no default broad grants)
- 🔒 **Row-Level Security** — a `region_access_map` table joined against `SESSION_USER()` so analytics readers only ever see rows scoped to their own region

### ⚙️ `.github/workflows/poka-yoke-gate.yml` — Fail-Closed CI/CD Gate (Task 2)
- ✅ Lint & format checks (flake8 + black for Django, ESLint for React)
- 🕵️ **gitleaks** — real, open-source secret scanner across full git history
- 🛡️ A custom check tuned for this stack — catches hardcoded Django `SECRET_KEY`s and raw GCP service-account keys
- 🚫 `deploy` only runs if **every single gate** passes — the default is "no deploy," not "deploy unless something breaks"

### 🧩 `backend/onboarding/` — DCYN Schema Validation (Task 3)
- 🔢 **DCYN library** (`dcyn.py`) — Deconstructed Clean Yes/No: every yes/no form answer is checked against a strict allow-list (`yes/y/true/1`, `no/n/false/0`). Anything ambiguous is **rejected**, never guessed at
- 🧬 `models.py` — mirrors the BigQuery schema field-for-field, so the app and the analytics sink never drift apart
- 📝 `serializers.py` — exact field limits, closed choice sets, and a hard-reject rule: no guardian consent, no saved record

### 🎞️ `slides/` — Presentation deck
A 14-slide walkthrough of the architecture, the fail-closed demo, and the design principles tying it all together.

---

## 🟢 Live proof it actually works

Check the **Actions** tab on this repo — it shows the pipeline running for real:
- 🔴 An early run that **failed and blocked deploy**
- 🟢 A later run where **every gate passed and deploy succeeded**

That's the fail-closed behavior from Task 2, demonstrated live rather than just described. ✨

---

Thanks for reading! 🙌
