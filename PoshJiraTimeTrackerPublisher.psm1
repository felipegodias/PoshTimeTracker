using module ./PoshTimeTracker.psm1

param (
    [Parameter(Mandatory = $true)]
    [string]$ConfigFilePath
)

function Publish-TimerEntryToJira {
    $Publisher = [JiraTimeTrackerPublisher]::new($ConfigFilePath)
    $PublishedEntries = $Global:StartTimerModule.PublishEntries($Publisher)
    $PublishedEntries | Format-Table -Property *, Duration
}

Set-Alias -Name pbtej -Value Publish-TimerEntryToJira
Export-ModuleMember -Function Publish-TimerEntryToJira -Alias pbtej

class JiraTimeTrackerPublisher : TimeTrackerPublisher {
    [JiraTimeTrackerPublisherConfig]$Config

    JiraTimeTrackerPublisher([string]$ConfigFilePath) {

        $ConfigFileContent = Get-Content -Path $ConfigFilePath
        if ($null -eq $ConfigFileContent) {
            throw
        }

        $ConfigFileYaml = $ConfigFileContent | ConvertFrom-Yaml 
        $this.Config = [JiraTimeTrackerPublisherConfig]::new($ConfigFileYaml)
    }

    [bool]Publish([TimerEntry]$TimerEntry) {
        $JiraTicketId = $TimerEntry.Tag
        [uri]$Endpoint = "/rest/api/latest/issue/$JiraTicketId/worklog"
        [uri]$RequestUri = [uri]::new($this.Config.JiraUri, $Endpoint)

        $AuthBytes = [System.Text.Encoding]::ASCII.GetBytes("$($this.Config.JiraUser):$($this.Config.JiraApiKey)")
        $Auth = [System.Convert]::ToBase64String($AuthBytes)

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

class JiraWorklLogRequestBody {
    [string]$started
    [Int64]$timeSpentSeconds
    [string]$comment

    JiraWorklLogRequestBody([TimerEntry]$TimerEntry) {
        $this.started = $TimerEntry.Start.ToString("yyyy-MM-dd'T'HH:mm:ss.fffzz00")
        $this.timeSpentSeconds = [Math]::Max($TimerEntry.Duration.TotalSeconds, 60)
        $this.comment = $TimerEntry.Description
    }
}

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
