using namespace System.Text
using module ./PoshTimeTracker.psm1

param (
    [Parameter(Mandatory = $true)]
    [string]$ConfigFilePath # Where this module should read the Jira configuration from.
)

# Publishes the umpublished entries from PoshTimeTracker.
function Publish-TimerEntryToJira {
    $Publisher = [JiraTimeTrackerPublisher]::new($ConfigFilePath)
    $PublishedEntries = $Global:StartTimerModule.PublishEntries($Publisher)

    # Display which entries were published or not.
    $PublishedEntries | Format-Table -Property *, Duration
}

Set-Alias -Name pbtej -Value Publish-TimerEntryToJira
Export-ModuleMember -Function Publish-TimerEntryToJira -Alias pbtej

# Jira publisher implementation for TimeTrackerPublisher abstraction.
class JiraTimeTrackerPublisher : TimeTrackerPublisher {
    [JiraTimeTrackerPublisherConfig]$Config

    JiraTimeTrackerPublisher([string]$ConfigFilePath) {
        $ConfigFileContent = Get-Content -Path $ConfigFilePath
        if ($null -eq $ConfigFileContent) {
            # Get-Content already prints the error message so ScriptHalted default value is okay in this case.
            throw
        }

        $ConfigFileYaml = $ConfigFileContent | ConvertFrom-Yaml
        $this.Config = [JiraTimeTrackerPublisherConfig]::new($ConfigFileYaml)
    }

    # Publishes the given Entry to Jira. Returns true if the request was successfuly made; otherwise, false.
    [bool]Publish([TimerEntry]$TimerEntry) {
        $JiraTicketId = $TimerEntry.Tag
        # https://developer.atlassian.com/cloud/jira/platform/rest/v3/api-group-issue-worklogs
        [uri]$Endpoint = "/rest/api/latest/issue/$JiraTicketId/worklog"
        [uri]$RequestUri = [uri]::new($this.Config.JiraUri, $Endpoint)

        # Authorization needs to be a basic combination of the JiraUser:ApiToken.
        $AuthBytes = [Encoding]::ASCII.GetBytes("$($this.Config.JiraUser):$($this.Config.JiraApiKey)")
        $Auth = [Convert]::ToBase64String($AuthBytes)

        $Headers = @{
            "Authorization" = "Basic $Auth"
        }

        $RequestBody = [JiraWorklLogRequestBody]::new($TimerEntry)
        $RequestBody = $RequestBody | ConvertTo-Json

        try {
            Write-Host "Submiting Entry with id '$($TimerEntry.Id)' and tag '$($TimerEntry.Tag)'..."
            Invoke-RestMethod -Uri $RequestUri `
                -Method POST `
                -ContentType "application/json" `
                -Headers $Headers `
                -Body $RequestBody
        }
        catch {
            $_ | Out-String | Write-Host
            return $false
        }

        return $true
    }
}

# Represents the POST request body for the worklog jira endpoint.
class JiraWorklLogRequestBody {
    [string]$started
    [Int64]$timeSpentSeconds
    [string]$comment

    JiraWorklLogRequestBody([TimerEntry]$TimerEntry) {
        # Jira expects the start date to be on the following format "2021-01-17T12:34:00.000+0000"
        $this.started = $TimerEntry.Start.ToString("yyyy-MM-dd'T'HH:mm:ss.fffzz00")

        # For some reason Jira only accept works with the time spent more than 60 seconds.
        $this.timeSpentSeconds = [Math]::Max($TimerEntry.Duration.TotalSeconds, 60)
        $this.comment = $TimerEntry.Description
    }
}

# Config file handler.
class JiraTimeTrackerPublisherConfig {
    [uri]$JiraUri
    [string]$JiraUser
    [string]$JiraApiKey

    JiraTimeTrackerPublisherConfig($Other) {
        $this.JiraUri = $Other.JiraUri
        $this.JiraUser = $Other.JiraUser
        $this.JiraApiKey = $Other.JiraApiKey
    }
}
