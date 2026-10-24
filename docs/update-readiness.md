# Update readiness check

The update readiness check answers one question before a maintenance window: **is this Azure Local system in a safe state to update, and if not, why?**

It is read-only. It never starts, resumes or cancels an update.

## What it reads

| Source | Used for |
| --- | --- |
| `Get-SolutionUpdateEnvironment` | Overall update state, current solution and SBE versions, readiness check state, date and individual results |
| `Get-SolutionUpdate` | Each pending, in-progress or failed update |
| `Get-SolutionUpdateRun` | The most recent run of a failed update, so the action plan instance ID can be passed to `Start-MonitoringActionplanInstanceToComplete` |
| `Get-Cluster` | Only used when the Lifecycle Manager cmdlets are missing, to tell an incomplete deployment apart from a non-cluster machine |

Run it on an Azure Local cluster node.

## Results

All results use the `Update` category.

### Lifecycle Manager

Reported only when `Get-SolutionUpdateEnvironment` is missing.

| Situation | Status | Meaning |
| --- | --- | --- |
| Cmdlet missing, node is in a cluster | Warning | The node is Arc-registered but the Azure Local deployment has not completed, so solution updates cannot be managed yet. Check the deployment in the Azure portal. |
| Cmdlet missing, not a cluster node | NotAvailable | Run the check on a cluster node. |

The first case comes from a real troubleshooting pattern: `Get-SolutionUpdateEnvironment` returning `CommandNotFoundException` on an Arc-registered cluster is easy to misread as a broken install, when the actual cause is an unfinished deployment.

### Update state

| `State` | Status |
| --- | --- |
| `AppliedSuccessfully`, `UpdateAvailable` | Healthy |
| `UpdateInProgress`, `PreparationInProgress`, `NeedsAttention` | Warning |
| `UpdateFailed`, `PreparationFailed` | Critical |
| anything else | Unknown |

An available update is Healthy: it is not a fault. The update itself is listed separately, with its version.

### Update readiness checks

| `HealthState` | Status |
| --- | --- |
| `Success` | Healthy, or Warning if the last run is older than `-HealthCheckMaxAgeDays` (default 7) |
| `Warning`, `InProgress` | Warning |
| `Failure`, `Error` | Critical |
| anything else | Unknown |

Stale results are flagged because a readiness check that passed weeks ago says little about the system today.

### Failed readiness checks

Reported only when `HealthCheckResult` contains checks whose `Status` is not `SUCCESS`. The result is Critical if any of those checks has `CRITICAL` severity, otherwise Warning, and lists up to five check titles.

To see every failing check with its remediation:

```powershell
(Get-SolutionUpdateEnvironment).HealthCheckResult |
    Where-Object Status -ne 'SUCCESS' |
    Format-List Title, Severity, Status, TargetResourceName, Description, Remediation
```

### Individual updates

Installed updates are skipped. If nothing else remains, a single Healthy `Pending updates` result is returned.

| Update `State` | Status | Guidance in the result |
| --- | --- | --- |
| `Ready`, `ReadyToInstall` | Healthy | Version that can be installed |
| `Downloading`, `Preparing`, `HealthChecking`, `Installing` | Warning | Progress, when `Installing` |
| `AdditionalContentRequired` | Warning | SBE content must be downloaded from the hardware vendor |
| `HasPrerequisite` | Warning | Another update must be installed first |
| `HealthCheckFailed` | Critical | Fix the readiness checks before installing |
| any other `...Failed` state | Critical | Last run state, start time and action plan instance ID; resume with `Start-SolutionUpdate` once fixed |
| anything else | Unknown | |

## Example

Synthetic output from a system with a failed update:

```text
Category Name                     Status   Details
-------- ----                     ------   -------
Update   Azure Local 2609         Critical State: InstallationFailed; Version: 12.2609.1002.18; Resume with Start-SolutionUpdate once the cause is fixed; Last run: Failed; Started: 2026-10-20T01:00:00; Action plan instance: 6f2b2c55-0000-4c1e-9f00-1234567890ab (see Start-MonitoringActionplanInstanceToComplete)
Update   Update readiness checks  Healthy  Readiness checks: Success; Last run: 2026-10-23 22:00 (0 day(s) ago)
Update   Update state             Critical State: UpdateFailed; Solution version: 12.2608.1001.4; SBE version: 4.1.2409.1; Review the failed run with Get-SolutionUpdate | Get-SolutionUpdateRun
```

## Only the update checks

```powershell
.\src\Get-AzureLocalHealth.ps1 | Where-Object Category -eq 'Update'
```
