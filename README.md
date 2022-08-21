<p align="center">
    <a href="https://github.com/felipegodias/PoshTimeTracker/graphs/contributors">
        <img src="https://img.shields.io/github/contributors/felipegodias/PoshTimeTracker.svg"/>
    </a>
    <a href="https://github.com/felipegodias/PoshTimeTracker/network/members">
        <img src="https://img.shields.io/github/forks/felipegodias/PoshTimeTracker.svg"/>
    </a>
    <a href="https://github.com/felipegodias/PoshTimeTracker/stargazers">
        <img src="https://img.shields.io/github/stars/felipegodias/PoshTimeTracker.svg"/>
    </a>
    <a href="https://github.com/felipegodias/PoshTimeTracker/issues">
        <img src="https://img.shields.io/github/issues/felipegodias/PoshTimeTracker.svg"/>
    </a>
    <a href="https://github.com/felipegodias/PoshTimeTracker/blob/master/LICENSE.txt">
        <img src="https://img.shields.io/github/license/felipegodias/PoshTimeTracker.svg"/>
    </a>
    <a href="https://www.linkedin.com/in/felipegodias">
        <img src="https://img.shields.io/badge/-LinkedIn-black.svg?logo=linkedin&colorB=1182c3"/>
    </a>
</p>

<div align="center">
    <img src="https://upload.wikimedia.org/wikipedia/commons/a/af/PowerShell_Core_6.0_icon.png?20180119125925" alt="Logo" width="128" height="130"/>
    <h1 align="center">PoshTimeTracker</h1>
</div>

## Requirements

-   PowerShell 7.x

```powershell
winget install Microsoft.PowerShell
```

-   [powershell-yaml](https://github.com/cloudbase/powershell-yaml) (For PoshJiraTimeTrackerPublisher only)

```powershell
Install-Module -Name powershell-yaml -AllowClobber -Scope CurrentUser -Force
```

## Install

```powershell
git clone git@github.com:felipegodias/PoshTimeTracker.git
Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy Unrestricted
```

### Powershell Profile

```powershell
Import-Module <REPOSITORY_PATH>/PoshTimeTracker.psm1 -ArgumentList <ENTRIES_SAVE_FILE_PATH>
Import-Module <REPOSITORY_PATH>/PoshJiraTimeTrackerPublisher.psm1 -ArgumentList <CONFIG_FILE_PATH>
```

## PoshTimeTracker

### Start-Timer (sat)

```powershell
Start-Timer [-Tag <TAG>] [-Description <DESCRIPTION>]
```

### Stop-Timer (stt)

```powershell
Stop-Timer
```

### Get-Timer (gte)

```powershell
Get-TimerEntry [-Tag <TAG>] [-From <FROM>] [-To <TO>]
```

### Remove-TimerEntry (rte)

```powershell
Remove-TimerEntry [-Id <ID>]
```

## PoshJiraTimeTrackerPublisher

### JiraConfig.yaml

```yaml
---
JiraUri: "https://<ORGANIZATION>.atlassian.net"
JiraUser: "<JIRA_USER>"
JiraApiKey: "<API_KEY>" # https://support.atlassian.com/atlassian-account/docs/manage-api-tokens-for-your-atlassian-account/
```

### Publish-TimerEntryToJira (pbtej)

```powershell
Publish-TimerEntryToJira
```
