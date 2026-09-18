# Contributing

Contributions, suggestions, and issue reports are welcome.

## Before contributing

Please make sure that examples, logs, scripts, screenshots, and test data do not contain:

- Organisation names that are not required for the example
- Internal hostnames
- Private IP addresses
- Tenant IDs
- Subscription IDs
- Resource IDs
- Access tokens
- Credentials
- Certificates or private keys

## Development approach

1. Create an issue describing the proposed change.
2. Create a branch for the work.
3. Keep changes focused and reusable.
4. Add or update documentation where relevant.
5. Open a pull request with a clear explanation of the change and how it was tested.

## PowerShell style

- Prefer approved PowerShell verbs.
- Use `[CmdletBinding()]` for reusable scripts and functions.
- Avoid hard-coded environment values.
- Handle expected failures explicitly.
- Return objects rather than formatted text where possible.
