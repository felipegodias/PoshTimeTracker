param(
    [string]$EntriesSaveFilePath
)

$Global:StartTimerModule = [StartTimerModule]::new($EntriesSaveFilePath)

function Start-Timer {
    param (
        [string]$Tag,
        [string]$Description
    )

    $Entry = $Global:StartTimerModule.StartTimer($Tag, $Description);
    $Entry | Format-Table -Property Id, Tag, Description, Start
}

function Stop-Timer {
    $Entry = $Global:StartTimerModule.StopTimer();
    $Entry | Format-Table -Property *, Duration
}

function Get-TimerEntry {
    param (
        [string]$Tag,
        [nullable[datetime]]$From,
        [nullable[datetime]]$To
    )

    $Entries = $Global:StartTimerModule.ReadEntries();
    [System.Linq.Enumerable]::Where($Entries, [Func[TimerEntry, bool]] {
            param ($TimerEntry)
            return ($Tag -eq "" -or $Tag -eq $TimerEntry.Tag) -and
                   ($null -eq $From -or $From -le $TimerEntry.Start) -and
                   ($null -eq $To -or $To -ge $TimerEntry.Start)
        }) | Format-Table -Property *, Duration
}

function Remove-TimerEntry {
    param (
        [int]$Id
    )

    $Entry = $Global:StartTimerModule.RemoveEntry($Id);
    $Entry | Format-Table -Property *, Duration
}

Set-Alias -Name sat -Value Start-Timer
Set-Alias -Name stt -Value Stop-Timer
Set-Alias -Name gte -Value Get-TimerEntry
Set-Alias -Name rte -Value Remove-TimerEntry
Export-ModuleMember -Function Start-Timer, Stop-Timer, Get-TimerEntry, Remove-TimerEntry -Alias sat, stt, gte, rte

class TimerEntry {
    [int]$Id
    [string]$Tag
    [string]$Description
    [datetime]$Start
    [nullable[datetime]]$End
    hidden [nullable[timespan]]$Duration

    TimerEntry([int]$Id, [string]$Tag, [string]$Description) {
        $this.Id = $Id;
        $this.Tag = $Tag;
        $this.Description = $Description;
        $this.Start = Get-Date;
        $this.End = $null;
        $this.Duration = $null
    }

    TimerEntry([PSCustomObject]$Other) {
        $this.Id = [int]::Parse($Other.Id)
        $this.Tag = $Other.Tag
        $this.Description = $Other.Description
        $this.Start = [datetime]::Parse($Other.Start)
        if ($null -ne $Other.End -and $Other.End -ne "") {
            $this.End = [datetime]::Parse($Other.End)
            $this.Duration = $this.End - $this.Start
        }
        else {
            $this.End = $null
            $this.Duration = $null
        }
    }
}

class StartTimerModule {
    [string]$EntriesSaveFilePath

    StartTimerModule([string]$EntriesSaveFilePath) {
        $this.EntriesSaveFilePath = $EntriesSaveFilePath
    }

    [System.Collections.Generic.List[TimerEntry]]ReadEntries() {
        if (Test-Path -Path $this.EntriesSaveFilePath) {
            return Import-Csv -Path $this.EntriesSaveFilePath
        }

        return [System.Collections.Generic.List[TimerEntry]]::new()
    }

    WriteEntries([System.Collections.Generic.List[TimerEntry]] $Entries) {
        $Entries | Export-Csv -Path $this.EntriesSaveFilePath
    }

    [TimerEntry]StartTimer([string]$Tag, [string]$Description) {
        $this.StopTimer()

        $Entries = $this.ReadEntries();

        $Id = $Entries.Count -eq 0 ? 1 : $Entries[$Entries.Count - 1].Id + 1
        $Entries.Add([TimerEntry]::new($Id, $Tag, $Description))

        $this.WriteEntries($Entries);
        return $Entries[$Entries.Count - 1]
    }

    [TimerEntry]StopTimer() {
        $Entries = $this.ReadEntries()
        if ($Entries.Count -eq 0) {
            return $null
        }

        $LastEntry = $Entries[$Entries.Count - 1]
        if ($null -ne $LastEntry.End) {
            return $null
        }

        $LastEntry.End = Get-Date
        $this.WriteEntries($Entries)
        return $LastEntry
    }

    [TimerEntry]RemoveEntry([int]$Id) {
        $Entries = $this.ReadEntries()
        
        $Entry = [System.Linq.Enumerable]::FirstOrDefault($Entries, [Func[TimerEntry, bool]] {
                param ($TimerEntry)
                return $Id -eq $TimerEntry.Id
            })

        $Entries.Remove($Entry)
        $this.WriteEntries($Entries)

        return $Entry
    }
}
