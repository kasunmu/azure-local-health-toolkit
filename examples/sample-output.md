# Sample output

The examples below are illustrative and do not represent a real production environment.

## Healthy example

```text
Category        Name                              Status        Details
--------        ----                              ------        -------
Arc             Azure Connected Machine Agent     Healthy       azcmagent show completed successfully.
Cluster         Cluster service                   Healthy       Cluster AZLOCAL-DEMO is reachable
ClusterNode     NODE-01                           Healthy       State: Up
ClusterNode     NODE-02                           Healthy       State: Up
CSV             Cluster Virtual Disk              Healthy       State: Online
NetworkATC      Intent management_compute         Healthy       Detected intent roles: Management, Compute
ManagementVnic  vManagement(management_compute)   Healthy       Expected Management OS vNIC name is present.
WDAC            Application Control mode          Healthy       Kernel-mode CI: Enforced; User-mode CI: Audit
StoragePool     S2D on Cluster                    Healthy       HealthStatus: Healthy; OperationalStatus: OK
VirtualDisk     ClusterPerformance...             Healthy       HealthStatus: Healthy; OperationalStatus: OK
PhysicalDisk    NVMe Disk                         Healthy       HealthStatus: Healthy; OperationalStatus: OK
```

## Synthetic pre-update warning example

This example shows the condition the Management OS vNIC check is designed to surface before an Azure Local update:

```text
Category        Name                              Status   Details
--------        ----                              ------   -------
NetworkATC      Intent management_compute         Healthy  Detected intent roles: Management, Compute
ManagementVnic  vManagement(management_compute)   Warning  Expected Management OS vNIC name 'vManagement(management_compute)' was not found and one or more GUID-style virtual adapter names were detected.
WDAC            Application Control mode          Healthy  Kernel-mode CI: Enforced; User-mode CI: Enforced
```

The GUID value itself is intentionally omitted from this public example.

## JSON export example

```json
[
  {
    "Category": "ClusterNode",
    "Name": "NODE-01",
    "Status": "Healthy",
    "Details": "State: Up",
    "Timestamp": "2026-09-18T15:00:00.0000000+01:00"
  }
]
```

All names and values shown here are synthetic.
