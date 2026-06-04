# 🔄 Automated Pricing Tier Optimization

> This Pull Request was generated automatically by the **CloudGuard Sentinel Pricing Auto-Scale** workflow.

---

## ✅ Pre-Submission Checklist

* [x] Change purpose checkbox(es) are updated
* [x] Change has been described below

## 🎯 Purpose

* [x] ~~New/~~ Updated Infrastructure configuration
* [ ] New/updated Analytic Rule(s)
* [ ] Bug Fix

## 📝 Description

The scheduled GitHub Actions workflow (**CloudGuard-SentinelPricingAutoScale**) has analyzed the current data ingest patterns across your Sentinel workspaces and determined that one or more pricing tiers should be adjusted for optimal cost efficiency.

**What changed:** ARM template parameter files have been updated to reflect the recommended pricing tiers based on the last 31 days of data ingest.

> ⚠️ **Please review the parameter file changes carefully before approving this PR.**
