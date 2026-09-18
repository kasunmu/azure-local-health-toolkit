# Sample output

The example below is illustrative and does not represent a real production environment.

```text
Category       Name                   Status        Details
--------       ----                   ------        -------
Arc            Azure Connected...     Healthy       azcmagent show completed successfully.
Cluster        Cluster service        Healthy       Cluster AZLOCAL-DEMO is reachable
ClusterNode    NODE-01                Healthy       State: Up
ClusterNode    NODE-02                Healthy       State: Up
CSV            Cluster Virtual Disk   Healthy       State: Online
StoragePool    S2D on Cluster         Healthy       HealthStatus: Healthy; OperationalStatus: OK
VirtualDisk    ClusterPerformance...  Healthy       HealthStatus: Healthy; OperationalStatus: OK
PhysicalDisk   NVMe Disk              Healthy       HealthStatus: Healthy; OperationalStatus: OK
```

JSON export example:

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
