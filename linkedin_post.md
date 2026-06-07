# LinkedIn Post — dbt E-Commerce Analytics Pipeline

---

I rebuilt a messy 8-table e-commerce database using dbt. Here's the lineage graph — and why this architecture means a dashboard never silently breaks again.

[INSERT YOUR DAG SCREENSHOT HERE]

The problem most data teams live with:
→ SQL logic scattered across 47+ ad-hoc scripts
→ Nobody knows which one is the source of truth
→ Someone changes a table upstream, three dashboards break — silently

The fix isn't more discipline. It's architecture.

Here's what I built using the Olist Brazilian E-Commerce dataset (100k+ real orders, 8 relational tables):

**Raw → Staging → Intermediate → Marts**

Each layer has exactly one job:
- Staging cleans and renames raw data (no business logic)
- Intermediate joins tables and computes CLV, seller scores
- Marts are pre-aggregated tables that feed Tableau directly

The result: 13 models, 81 automated data quality tests, and a lineage graph that shows every dependency at a glance.

When a raw table changes, a test fails loudly before any dashboard sees bad data. That's the difference between data engineering and data chaos.

Tech stack: dbt Core · Snowflake · Python · Tableau

GitHub: [your repo link]

If you're still running ad-hoc SQL scripts and calling it a pipeline, this project is worth a look.

---

#DataEngineering #AnalyticsEngineering #dbt #Snowflake #SQL #DataQuality #Portfolio

---

POSTING TIPS:
- Post the DAG screenshot as the first image — it gets clicks because it looks impressive and visual
- Post in the morning (Tuesday–Thursday, 8–10am) for best reach
- In the first comment, add: "Full write-up and code: [GitHub link]"
- Tag 2-3 people who might find it useful (keeps it off the promotional feed)
