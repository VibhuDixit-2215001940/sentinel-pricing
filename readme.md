<div align="center">

# ⚡ Sentinel Pricing Optimizer

### Intelligent Cost Optimization for Microsoft Sentinel & Log Analytics

[![PowerShell](https://img.shields.io/badge/PowerShell-7.0+-5391FE?style=for-the-badge&logo=powershell&logoColor=white)](https://github.com/PowerShell/PowerShell)
[![Azure](https://img.shields.io/badge/Microsoft_Azure-0078D4?style=for-the-badge&logo=microsoft-azure&logoColor=white)](https://azure.microsoft.com)
[![Sentinel](https://img.shields.io/badge/Microsoft_Sentinel-0078D4?style=for-the-badge&logo=microsoft&logoColor=white)](https://azure.microsoft.com/en-us/products/microsoft-sentinel)

*Stop overpaying for your Azure SIEM. Let automation find the optimal pricing tier for every workspace.*

---

</div>

## 📖 Background & Motivation

Microsoft Sentinel and Log Analytics use a tiered pricing model where **capacity reservation** tiers become cheaper than **pay-as-you-go** after certain data ingest thresholds. However, these breakeven points are not obvious and many organizations end up overpaying without realizing it.

This tool was built to solve that problem — it automatically analyzes your actual data usage and recommends the most cost-effective tier.

---

## 🎯 What It Does

| Step | Action | Detail |
|:---:|--------|--------|
| **1** | 🔍 Subscription Scan | Loops through all Azure subscriptions you have access to |
| **2** | 📊 Data Ingest Query | Executes KQL queries on each workspace to calculate 31-day average daily ingest |
| **3** | 💡 Tier Comparison | Compares usage against pricing threshold tables for Log Analytics |
| **4** | 🛡️ Sentinel Check | Detects Sentinel-enabled workspaces and applies separate Sentinel thresholds |
| **5** | 📋 Report Generation | Outputs results as a formatted table + CSV export |
| **6** | ✏️ ARM Auto-Update | Optionally updates ARM template parameter files with optimal values |

---

## 🚀 Quick Start

### Prerequisites

- **PowerShell 7+** (Core Edition)
- Azure modules: `Az.Accounts`, `Az.OperationalInsights`, `Az.MonitoringSolutions`
- Azure account with **Reader** access to target subscriptions

### Basic Usage (Report Only)

```powershell
./powershell-script/AzSentinelPricingOptimizer.ps1
```

### Target a Specific Subscription

```powershell
./powershell-script/AzSentinelPricingOptimizer.ps1 `
    -subscriptionId '<your-subscription-id>'
```

### Auto-Update ARM Parameters

```powershell
./powershell-script/AzSentinelPricingOptimizer.ps1 `
    -subscriptionId '<your-subscription-id>' `
    -updateArmParameters $true `
    -parametersFilePath 'arm-templates/'
```

---

## ⚙️ Parameters Reference

| Parameter | Required | Default | Description |
|-----------|:--------:|---------|-------------|
| `subscriptionId` | No | *all subs* | Limit scan to a single Azure subscription |
| `updateArmParameters` | No | `$false` | When `$true`, writes optimal SKU values to ARM parameter files |
| `parametersFilePath` | No | *prompted* | Path to ARM template parameter files directory |

> **Note:** When using `updateArmParameters`, the script expects parameter file names to match workspace names (e.g., workspace `log-sentinel-weeu` → file `log-sentinel-weeu.parameters.json`)

---

## 📊 Pricing Tier Thresholds

The thresholds below are calculated from **West Europe list prices**. If your region or pricing differs, use the bundled Excel calculator to recalculate.

<table>
<tr>
<th>Log Analytics Tier</th>
<th>Threshold (GB/day)</th>
<th>Sentinel Tier</th>
<th>Threshold (GB/day)</th>
</tr>
<tr><td>Pay-as-you-go</td><td>0</td><td>Pay-as-you-go</td><td>0</td></tr>
<tr><td>100 GB/day</td><td>85</td><td>100 GB/day</td><td>50</td></tr>
<tr><td>200 GB/day</td><td>188</td><td>200 GB/day</td><td>180</td></tr>
<tr><td>300 GB/day</td><td>293</td><td>300 GB/day</td><td>289</td></tr>
<tr><td>400 GB/day</td><td>391</td><td>400 GB/day</td><td>385</td></tr>
<tr><td>500 GB/day</td><td>491</td><td>500 GB/day</td><td>480</td></tr>
<tr><td>1000 GB/day</td><td>983</td><td>1000 GB/day</td><td>975</td></tr>
<tr><td>2000 GB/day</td><td>1953</td><td>2000 GB/day</td><td>1897</td></tr>
<tr><td>5000 GB/day</td><td>4849</td><td>5000 GB/day</td><td>4730</td></tr>
</table>

---

## 🔄 Automated Auto-Scaling (CI/CD)

A GitHub Actions workflow is included for fully automated monthly pricing optimization:

1. Copy `github-workflow/sentinel-pricing-auto-scale.yml` → `.github/workflows/`
2. Copy `github-workflow/pull-request-template.md` → `.github/PULL_REQUEST_TEMPLATE_PRICING_TIER.md`
3. Configure environment secrets: `CLIENTID`, `TENANTID`, `SUBSCRIPTIONID`
4. The workflow runs on the **1st of every month** — it scans, updates ARM files, and opens a PR

---

## 📁 Repository Structure

```
sentinel-pricing/
├── 📂 powershell-script/
│   └── AzSentinelPricingOptimizer.ps1      # Core optimization script
├── 📂 arm-templates/
│   ├── sentinel-workspace.template.json    # ARM deployment template
│   └── log-sentinel-weeu.parameters.json   # Sample parameters file
├── 📂 excel-calculator/
│   └── sentinel-pricing-tiers-*.xlsx       # Threshold calculator spreadsheet
├── 📂 github-workflow/
│   ├── sentinel-pricing-auto-scale.yml     # GitHub Actions workflow
│   └── pull-request-template.md            # PR template for auto-scaling
└── 📄 readme.md                            # This file
```

---

## 🤝 Contributing

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/improvement`)
3. Commit your changes (`git commit -m 'Add improvement'`)
4. Push to the branch (`git push origin feature/improvement`)
5. Open a Pull Request

---

<div align="center">

**Maintained by Vibhu Dixit @ CloudGuard Security**

*Reduce cloud costs. Automate optimization. Sleep better.*

</div>
