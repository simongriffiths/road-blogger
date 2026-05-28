Here's a handover prompt you can drop directly into Codex:

---

**Context**

I am building a blog subscriber module as part of the ROAD kit — an open-source framework using React, ORDS, ADB (Oracle Autonomous Database), and Direct calls (no middleware). The module is intended as a reusable ROAD kit reference implementation.

The attached archive (`subscriber-module-m7.tar.gz`) contains the current state of the subscriber module: database schema, PL/SQL packages, ORDS endpoint definitions, Hugo frontend integration, scheduler jobs, GDPR functions, a test script, and documentation.

**The ROAD kit repo is the authoritative source for:**
- React component patterns, routing, and shared UI components
- How ORDS API calls are structured from React (fetch wrapper, auth handling, error patterns)
- CSS design tokens and shared stylesheets
- The file upload mechanism (uploads static files to ADB)
- Build and deploy pipeline (how React apps are built and fed into the upload script)
- General PL/SQL and ORDS conventions (file naming, package structure, deployment patterns)

**What I need you to evaluate:**

1. **Known defects to fix first:**
   - `sub_email.render_email_wrapper()` is a private function in the package body but is called from `sub_newsletter`. It must be promoted to the `sub_email` package spec to be visible externally.
   - `sub_gdpr.pks` contains both the package spec and body in a single file named `.pks`. This should be split into `sub_gdpr.pks` (spec only) and `sub_gdpr.pkb` (body only) per ROAD kit conventions.
   - The `admin` ORDS module is partially defined in `ords_admin_gdpr.sql` but is otherwise unbuilt. M5 (the React admin UI and its backing ORDS endpoints) has not been built yet.

2. **ROAD kit alignment review:**
   - Review all SQL files against ROAD kit conventions (file naming, one artifact per file, DROP scripts, dependency ordering, SQLcl runner patterns). Flag any deviations.
   - Review the ORDS module definitions against how existing ROAD kit modules are structured.
   - Review `subscribe.js` and the Hugo partial against any existing frontend patterns in the kit.

3. **M5 — Admin UI (not yet built):**
   This is the main outstanding milestone. The admin UI requires:
   - A React single-page application served from ORDS static files
   - Protected by ORDS First Party Auth (database user credentials, session cookie)
   - Four sections: Dashboard, Subscriber List, Newsletter Composer, Send History
   - The newsletter composer uses a template upload workflow: HTML templates are edited locally and uploaded to ADB via the existing ROAD file upload mechanism, stored as CLOBs in a `NEWSLETTER_TEMPLATES` table (not yet in the schema). The composer selects a template, fills in placeholder values (`{{subject}}`, `{{first_name}}`, `{{unsubscribe_url}}`, `{{pixel_url}}`, `{{blog_url}}`, `{{current_date}}`), previews the result, and queues the send.
   - Analytics views (`V_SEND_SUMMARY`, `V_SUBSCRIBER_GROWTH`) are already in the schema and should back the dashboard and send history sections.
   - The subscriber list needs search, status filter, manual delete (calling `sub_gdpr.erase_subscriber`), and CSV export.

   Please assess how much of the existing ROAD kit React infrastructure can be reused for M5, and propose the build approach before writing any code.

4. **Missing ORDS admin endpoints for M5:**
   The admin UI will need ORDS endpoints for: subscriber list (GET), subscriber delete (DELETE), newsletter template management (GET/POST), send queue (POST to queue a send, GET for status), and send history (GET). These do not yet exist. Please design these consistently with existing ROAD kit ORDS patterns before building the React UI against them.

**Constraints:**
- Serverless — no compute VMs, no self-hosted middleware, managed ADB and ORDS only
- Same-origin — blog, subscriber module, and admin UI all served from the same ADB/ORDS instance
- OCI Always Free tier compatible
- ROAD kit conventions throughout

**Deliverables expected:**
1. Defect fixes (items in point 1 above)
2. ROAD kit alignment review with any corrections applied
3. M5 build proposal for review before implementation
4. M5 implementation once proposal is approved

---

That gives Codex full context, the known defects upfront, clear M5 scope, and the right sequencing — fix and align before building.
