<#

    AzSentinelPricingOptimizer.ps1
    
    V1.0 - Enhanced Edition | Maintained by Vibhu Dixit @ CloudGuard Security

    Sentinel & Log Analytics Pricing Tier Optimizer
    ================================================
    Analyzes all Log Analytics workspaces across your Azure subscriptions to identify the most
    cost-effective pricing tier configuration. Supports both Log Analytics and Microsoft Sentinel
    pricing layers with separate threshold calculations.
    
    Workflow:
        [1] Iterates through all accessible Azure subscriptions
        [2] Queries each Log Analytics workspace for 31-day average daily data ingest via KQL
        [3] Compares ingest against pricing threshold tables to determine optimal tier
        [4] Detects Sentinel-enabled workspaces and applies Sentinel-specific thresholds
        [5] Aggregates results into a formatted report and exports to CSV

    Note: Pricing thresholds are based on West Europe list prices (Feb 2022).
    Use the included Excel calculator to recalculate for your region or discounted rates.

#>

[CmdletBinding()]
param (

    [Parameter (Mandatory = $false)]
    [String] $subscriptionId = "",

    [Parameter (Mandatory = $false)]
    [bool] $updateArmParameters = $false,

    [Parameter (Mandatory = $false)]
    [String] $parametersFilePath = ""

)

# Requires PowerShell Core (v7+) to execute
#Requires -PSEdition Core

Clear-Host

Write-Host ""
Write-Host "  ╔══════════════════════════════════════════════════════════════════════╗" -ForegroundColor Magenta
Write-Host "  ║                                                                      ║" -ForegroundColor Magenta
Write-Host "  ║   ░██████╗███████╗███╗  ██╗████████╗██╗███╗  ██╗███████╗██╗          ║" -ForegroundColor Cyan
Write-Host "  ║   ██╔════╝██╔════╝████╗ ██║╚══██╔══╝██║████╗ ██║██╔════╝██║          ║" -ForegroundColor Cyan
Write-Host "  ║   ╚█████╗ █████╗  ██╔██╗██║   ██║   ██║██╔██╗██║█████╗  ██║          ║" -ForegroundColor Cyan
Write-Host "  ║    ╚═══██╗██╔══╝  ██║╚████║   ██║   ██║██║╚████║██╔══╝  ██║          ║" -ForegroundColor Cyan
Write-Host "  ║   ██████╔╝███████╗██║ ╚███║   ██║   ██║██║ ╚███║███████╗███████╗     ║" -ForegroundColor Cyan
Write-Host "  ║   ╚═════╝ ╚══════╝╚═╝  ╚══╝   ╚═╝   ╚═╝╚═╝  ╚══╝╚══════╝╚══════╝     ║" -ForegroundColor Cyan
Write-Host "  ║                                                                      ║" -ForegroundColor Magenta
Write-Host "  ║   ██████╗ ██████╗ ██╗ ██████╗██╗███╗  ██╗ ██████╗                    ║" -ForegroundColor DarkYellow
Write-Host "  ║   ██╔══██╗██╔══██╗██║██╔════╝██║████╗ ██║██╔════╝                    ║" -ForegroundColor DarkYellow
Write-Host "  ║   ██████╔╝██████╔╝██║██║     ██║██╔██╗██║██║  ██╗                    ║" -ForegroundColor DarkYellow
Write-Host "  ║   ██╔═══╝ ██╔══██╗██║██║     ██║██║╚████║██║  ╚██╗                   ║" -ForegroundColor DarkYellow
Write-Host "  ║   ██║     ██║  ██║██║╚██████╗██║██║ ╚███║╚██████╔╝                   ║" -ForegroundColor DarkYellow
Write-Host "  ║   ╚═╝     ╚═╝  ╚═╝╚═╝ ╚═════╝╚═╝╚═╝  ╚══╝ ╚═════╝                   ║" -ForegroundColor DarkYellow
Write-Host "  ║                                                                      ║" -ForegroundColor Magenta
Write-Host "  ║          ◆  OPTIMIZER  ◆  Auto-Scale  ◆  Cost Saver  ◆               ║" -ForegroundColor White
Write-Host "  ║                                                                      ║" -ForegroundColor Magenta
Write-Host "  ╚══════════════════════════════════════════════════════════════════════╝" -ForegroundColor Magenta
Write-Host "          CLOUDGUARD SECURITY // sentinel pricing optimizer" -ForegroundColor DarkGray
Write-Host ""

# Check if Arm template parameters file path is correctly passed as parameter, otherwise ask for it

if ($updateArmParameters) {
    if($parametersFilePath -eq "") {
        Write-Host "No Arm template parameters file path provided!" -ForegroundColor Red
        $parametersFilePath = Read-Host "Please provider proper file path"
    } else {
        if (!(Test-Path $parametersFilePath)) {
            Write-Host "Path provided is invalid!" -ForegroundColor Red
            $parametersFilePath = Read-Host "Please provider proper file path"
            if (!(Test-Path $parametersFilePath)) {
                Write-Host "Path provided is still invalid! Exiting script..." -ForegroundColor Red
                Write-Host ""
                Exit
            }
            else {
                Write-Host "Path appeared to be valid, continueing script..." -ForegroundColor Green
                Write-Host ""
            }
        } else {
            Continue
        }
    }
}

# ── Module dependency check ──────────────────────────────────────────────────

    $modulesToInstall = @(
        'Az.Accounts',
        'Az.OperationalInsights',
        'Az.MonitoringSolutions'
    )
    Write-Host "[*] Checking required PowerShell modules..." -ForegroundColor Cyan
    $modulesToInstall | ForEach-Object {
        if (-not (Get-Module -ListAvailable $_)) {
            Write-Host "  ├─ Module [$_] not found, installing..." -ForegroundColor DarkYellow
            Install-Module $_ -Force
        } else {
            Write-Host "  ├─ Module [$_] already installed." -ForegroundColor DarkGray
        }
    }

    $modulesToInstall | ForEach-Object {
        if (-not (Get-InstalledModule $_)) {
            Write-Host "  ├─ Module [$_] not loaded, importing..." -ForegroundColor DarkYellow
            Import-Module $_ -Force
        } else {
            Write-Host "  ├─ Module [$_] already loaded." -ForegroundColor DarkGray
        }
    }

# ── Variable initialization ──────────────────────────────────────────────────

    $logAnalyticsPriceTable = @{}
    $sentinelPriceTable = @{}
    $listworkspace = @{}
    $sentinelWorkspaces = @()
    $changeRequired = $false
    $count = [int]1

# ── Pricing thresholds: West Europe region ───────────────────────────────────
# Source: https://azure.microsoft.com/en-us/pricing/details/monitor/

    $logAnalyticsPriceTable = @{
        'PerGB2018' = [int]    0;
        '100'       = [int]   85; 
        '200'       = [int]  188;
        '300'       = [int]  293;
        '400'       = [int]  391;
        '500'       = [int]  491;
        '1000'      = [int]  983;
        '2000'      = [int] 1953;
        '5000'      = [int] 4849
    }

# Source: https://azure.microsoft.com/en-us/pricing/details/microsoft-sentinel/

    $sentinelPriceTable = @{
        'PerGB'     = [int]    0;
        '100'       = [int]   50; 
        '200'       = [int]  180;
        '300'       = [int]  289;
        '400'       = [int]  385;
        '500'       = [int]  480;
        '1000'      = [int]  975;
        '2000'      = [int] 1897;
        '5000'      = [int] 4730
    }

# ── KQL Queries ──────────────────────────────────────────────────────────────
# Average daily data ingest over the last 31 days (excluding current day)

$DailyAvgIngestQuery = @'
    Usage
    | where TimeGenerated > ago(31d) and TimeGenerated < ago(1d)
    // Only look at chargeable Tables
    | where IsBillable == True
    | summarize TotalGBytes =round(sum(Quantity/(1000)),2) by bin(TimeGenerated, 1d)
    | summarize ['GBs/day'] =round(avg(TotalGBytes),2)
'@

$LogAnalyticsRetentionQuery = @'
    Usage
    // Data older than 30 days is billed for additional retention
    | where TimeGenerated < ago(30d)
    // Only look at chargeable Tables
    | where IsBillable == true
    | summarize PayedRetentionGB = round(sum(Quantity) / 1000 , 0)
'@

$SentinelRetentionQuery = @'
    Usage
    // Data older than 90 days is billed for additional retention
    | where TimeGenerated < ago(90d)
    // Only look at chargeable Tables
    | where IsBillable == true
    | summarize PayedRetentionGB = round(sum(Quantity) / 1000 , 0)
'@

if(!$subscriptionId){
    $subscriptions = Get-AzSubscription    
} else {
    $subscriptions = Get-AzSubscription -SubscriptionId $subscriptionId
}

foreach($subscription in $subscriptions) {

    $subscriptionId = $subscription.SubscriptionId

    Write-Host ""
    Write-Host "▶ [$($count)/$($subscriptions.Count)] Selecting Azure subscription '$($subscription.Name)'" -ForegroundColor Cyan
    Select-AzSubscription -subscriptionId $subscriptionId | Out-Null

    # Retrieve all log analytics workspaces (exclude Defender for Cloud default workspaces)
    $workspaces = Get-AzOperationalInsightsWorkspace | Where-Object { $_.Name -notlike "DefaultWorkspace-*" }

    if(!$workspaces) {
        Write-Host "  ✖ No workspaces found in this subscription" -ForegroundColor DarkGray
    } else {
    
        foreach ($workspace in $workspaces) {
        
            Write-Host ""
            Write-Host "╔═══════════════════════════════════════════════════════════" -ForegroundColor Magenta
            Write-Host "║  Investigating workspace: $($workspace.Name)" -ForegroundColor Magenta
            Write-Host "╚═══════════════════════════════════════════════════════════" -ForegroundColor Magenta
            $changeRequired = $false

            # Retrieve current Log Analytics Sku
            if ($workspace.Sku -eq "free") {
                $currentSku = "Free"
            } else {
                if ($workspace.Sku -eq "PerGB2018") {
                    $currentSku = "PerGB2018"
                }
                elseif ($workspace.Sku -eq "standalone") {
                    $currentSku = "Standalone"
                }
                else {
                    $currentSku = $workspace.CapacityReservationLevel
                }
            }
            
            # Query for average daily date ingest
            Write-Host "  ├─ Querying for average daily data ingest..." -ForegroundColor Gray
            $queryResults = Invoke-AzOperationalInsightsQuery -WorkspaceId $workspace.CustomerId -Query $DailyAvgIngestQuery -Wait 120 | Select-Object Results
            $avgDailyIngest = ($queryResults.Results | Select-Object -ExpandProperty "GBs/day")
            if ($avgDailyIngest -eq "NaN") {
                # In case KQL gave no results, the daily data ingest = zero
                $avgDailyIngest = 0
            }
        
            # Compare the daily data ingest with the values of the pricing hash table defined above
            $loganalyticsAllRecommendations = $logAnalyticsPriceTable.GetEnumerator() | Where-Object { $_.Value -le $avgDailyIngest }
        
            # Next, we want to show only the pricing tier with the highest amount of data/day aplicable
            if ($currentSku -eq "Free") {
                $optimalSku = "Free"
            } else {
                $getSku = $loganalyticsAllRecommendations | Where-Object { $_.Value -eq (($loganalyticsAllRecommendations | measure-object -Property Value -maximum).maximum) } | Select-Object -ExpandProperty Name
                if (($getSku -eq 'PerGB2018') -and ($currentSku -eq 'Standalone')) {
                    # Standalone is cheaper then PerGB2018
                    $optimalSku = $currentSku
                } elseif ($getSku -eq 'PerGB2018') {
                    # Check if Sku = string
                    $optimalSku = $getSku
                } else {
                    $optimalSku = [int]$getSku      # Otherwise it's an integer
                }
            }
        
            # Check is Sentinel solution is enabled on the log analytics workspace
            Write-Host "  ├─ Check if workspace is Sentinel enabled..." -ForegroundColor Gray
            $checkSentinelEnabled = Get-AzMonitorLogAnalyticsSolution | Where-Object { $_.Name -eq "SecurityInsights($($workspace.Name))" }
            Write-Host "  ├─ Gathering Log Analytics pricing tier recommendations..." -ForegroundColor Gray
            If (($checkSentinelEnabled | Measure-Object).Count -eq 0) {
                $sentinelEnabled = $false
                # Then also no Sentinel pricing tier is aplicable
                $optimalSentinelSku = "N/A"
                $currentSentinelSku = "N/A"
            }
            else {
                $sentinelEnabled = $true
                # Retrieve current Sentinel SKU
                $context = Get-AzContext
                $profileClient = [Microsoft.Azure.Commands.ResourceManager.Common.RMProfileClient]::new([Microsoft.Azure.Commands.Common.Authentication.Abstractions.AzureRmProfileProvider]::Instance.Profile)
                $token = $profileClient.AcquireAccessToken($context.Subscription.TenantId)
                $headers = @{
                    "Authorization" = "Bearer $($token.AccessToken)"
                    "Content-Type"  = "application/json"
                }
                Write-Host "  ├─ Retrieving current Sentinel SKU..." -ForegroundColor Gray
                $params = @{
                    "Method"  = "Get"
                    "Uri"     = "https://management.azure.com/subscriptions/$subscriptionId/resourceGroups/$($workspace.ResourceGroupName)/providers/Microsoft.OperationsManagement/solutions/SecurityInsights($($workspace.Name))?api-version=2015-11-01-preview"
                    "Headers" = $headers
                }
                $sentinelProperties = Invoke-RestMethod @params -UseBasicParsing
                if ($sentinelProperties.properties.sku.name -eq "PerGB") {
                    $currentSentinelSku = "PerGB"
                }
                else {
                    $currentSentinelSku = [int]$sentinelProperties.properties.sku.capacityReservationLevel
                }
                Write-Host "  ├─ Gathering Sentinel pricing tier recommendations..." -ForegroundColor Gray
                # Compare the daily data ingest with the values of the pricing hash table defined above
                $sentinelAllRecommendations = $sentinelPriceTable.GetEnumerator() | Where-Object { $_.Value -le $avgDailyIngest }
                # Next, we want to show only the pricing tier with the highest amount of data/day aplicable
                $getSentinelSku = $sentinelAllRecommendations | Where-Object { $_.Value -eq (($sentinelAllRecommendations | measure-object -Property Value -maximum).maximum) } | Select-Object -ExpandProperty Name
                if ($getSentinelSku -eq 'PerGB') {
                    # Check if Sku = string
                    $optimalSentinelSku = $getSentinelSku
                }
                else {
                    $optimalSentinelSku = [int]$getSentinelSku      # Otherwise it's an integer
                }
            }

            # Check data beyond free retention
            Write-Host "  ├─ Checking data retention..." -ForegroundColor Gray
            If ($sentinelEnabled -eq $false) {
                Write-Host "     └ Data older than free retention (30d)?..." -ForegroundColor DarkGray
                $queryResults = Invoke-AzOperationalInsightsQuery -WorkspaceId $workspace.CustomerId -Query $LogAnalyticsRetentionQuery -Wait 120 | Select-Object Results
                $billedRetentionGB = ($queryResults.Results | Select-Object -ExpandProperty "PayedRetentionGB")
            }
            If ($sentinelEnabled -eq $true) {
                Write-Host "     └ Data older than free retention (90d)?..." -ForegroundColor DarkGray
                $queryResults = Invoke-AzOperationalInsightsQuery -WorkspaceId $workspace.CustomerId -Query $SentinelRetentionQuery -Wait 120 | Select-Object Results
                $billedRetentionGB = ($queryResults.Results | Select-Object -ExpandProperty "PayedRetentionGB")
            }
            # Construct new hash table with information about this workspace
            $listworkspace = New-Object PSObject -property @{
                workspaceName      = $workspace.Name;
                SubscriptionName   = $subscription.Name;
                sentinelEnabled    = $sentinelEnabled;
                retentionInDays    = $workspace.retentionInDays;
                averageDailyIngest = $avgDailyIngest;
                currentSku         = $currentSku;
                optimalSku         = $optimalSku;
                currentSentinelSku = $currentSentinelSku;
                optimalSentinelSku = $optimalSentinelSku;
                billedRetentionGB  = $billedRetentionGB
            }
            # Add hash table to already existing object with all the other workspaces
            $sentinelWorkspaces += $listworkspace

            # Compare Current Sku's with optimal Sku's
            Write-Host "  ├─ Evaluating SKU optimization..." -ForegroundColor Gray
            if (($null -eq $currentSku) -or ($null -eq $optimalSku))   {
                Write-Host '     One of values for "$currentSku" or "$optimalSku" is "$null". Cannot continue comparison, check values in end result.' -ForegroundColor Red
            } else {
                if ($currentSku -eq 'Free') {
                    Write-Host "     ● Log Analytics SKU: N/A (running free tier)" -ForegroundColor Green
                }
                else {
                    if ($currentSku.Equals($optimalSku)) {
                        Write-Host "     ● Log Analytics SKU: Already optimal" -ForegroundColor Green
                    }
                    else {
                        Write-Host "     ▲ Log Analytics SKU: Change required [$($currentSku) → $($optimalSku)]" -ForegroundColor Yellow
                        $changeRequired = $true
                    }
                }
            }

            if (($null -eq $currentSentinelSku) -or ($null -eq $optimalSentinelSku))   {
                Write-Host '     One of values for "$currentSentinelSku" or "$optimalSentinelSku" is "$null". Cannot continue comparison, check values in end result.' -ForegroundColor Red
            } else {
                if ($currentSentinelSku -ne 'N/A') {
                    if ($currentSentinelSku.Equals($optimalSentinelSku)) {
                        Write-Host "     ● Sentinel SKU: Already optimal" -ForegroundColor Green
                    }
                    else {
                        Write-Host "     ▲ Sentinel SKU: Change required [$($currentSentinelSku) → $($optimalSentinelSku)]" -ForegroundColor Yellow
                        $changeRequired = $true
                    }
                }            
            }

            If ($updateArmParameters) {
                # Make adjustments to ARM template parameters file
                if ($changeRequired) {
                    # Read ARM template parameters file
                    $parametersFile = (Get-ChildItem $parametersFilePath | where-object name -match $listworkspace.workspaceName).Name
                    $parametersFileContents = Get-Content $parametersFile | ConvertFrom-Json

                    # Change Log Analytics parameters values to match optimal Sku
                    If ($optimalSku -eq "PerGB2018") {
                        $parametersFileContents.parameters.pricingTierLogAnalytics.value = "PerGB2018"
                        $parametersFileContents.parameters.capacityReservationLevelLogAnalytics.value = 100
                    }
                    else {
                        $parametersFileContents.parameters.pricingTierLogAnalytics.value = "CapacityReservation"
                        $parametersFileContents.parameters.capacityReservationLevelLogAnalytics.value = $optimalSku
                    }

                    # Change Sentinel parameters values to match optimal Sku
                    If ($optimalSentinelSku -eq "perGB") {
                        $parametersFileContents.parameters.pricingTierSentinel.value = $false
                        $parametersFileContents.parameters.capacityReservationLevelSentinel.value = 100
                    }
                    else {
                        $parametersFileContents.parameters.pricingTierSentinel.value = $true
                        $parametersFileContents.parameters.capacityReservationLevelSentinel.value = $optimalSentinelSku
                    }
                
                    # Write changes to ARM template parameters file
                    Write-Host "  ├─ Writing ARM template parameters file to disk..." -ForegroundColor Gray
                    try {
                        $parametersFileContents | Convertto-Json | out-file $parametersFile
                        Write-Host "     ● ARM parameters file '$($parametersFile)' updated successfully" -ForegroundColor Green
                    }
                    catch {
                        Write-Host "     ✖ Failed to write ARM parameters file" -ForegroundColor Red
                    }
                
                    # Write Github variables for next step(s)
                    "fileChanges=true" >> $env:GITHUB_OUTPUT
                    "filePath=$parameterFile" >> $env:GITHUB_OUTPUT
                }
            }
        }
    }

    $Count++
    
}

# ── Final Report ─────────────────────────────────────────────────────────────

    Write-Host ""
    Write-Host ""
    Write-Host "╔═══════════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "║  RESULTS: Discovered Sentinel & Log Analytics Workspace(s)       ║" -ForegroundColor Cyan
    Write-Host "╚═══════════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
    $sentinelWorkspaces | Select-Object -Last 20 | Format-Table workspaceName, SubscriptionName, sentinelEnabled, retentionInDays, averageDailyIngest, currentSku, optimalSku, currentSentinelSku, optimalSentinelSku, billedRetentionGB
    # Notify if list is shortened
    If (($sentinelWorkspaces | Measure-Object).Count -gt 20) {
        Write-Host "[!] More than 20 workspaces found — output has been truncated." -ForegroundColor Red
    }
