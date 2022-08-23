using namespace System.Collections.Generic
using namespace System.Linq

param(
    [Parameter(Mandatory = $true)]
    [string]$EntriesSaveFilePath # Where this module should save the entries to.
)

$Global:StartTimerModule = [StartTimerModule]::new($EntriesSaveFilePath)

# Stops the latest Timer then starts a new one. The new Entry is displayed.
function Start-Timer {
    param (
        [string]$Tag,
        [string]$Description
    )

    $Entry = $Global:StartTimerModule.StartTimer($Tag, $Description)

    # Prints the newly started timer.
    $Entry | Format-Table -Property Id, Tag, Description, Start
}

# Stops the previous started timer. Prints the Entry if there was any.
function Stop-Timer {
    $Entry = $Global:StartTimerModule.StopTimer();

    # Prints the entry which was stopped.
    $Entry | Format-Table -Property *, Duration
}

# Gets the list of all registred entries.
function Get-TimerEntry {
    param (
        [string]$Tag, # The entry tag to be shown. If not set, show any.
        [switch]$Today,
        [switch]$Week,
        [nullable[DateTimeOffset]]$From, # Only Entries that started after FROM will be selected.
        [nullable[DateTimeOffset]]$To # Only entries that started before TO will be selected.
    )

    $TodaysDate = [DateTime]::Now.Date

    # Set From and To based on Today.
    if ($Today) {
        $From = $TodaysDate
        $To = $TodaysDate.AddDays(1)
    }

    # Set From and To based on the week.
    if ($Week) {
        $From = $TodaysDate.AddDays(-$TodaysDate.DayOfWeek)
        $To = $From.AddDays(7)
    }

    $Entries = $Global:StartTimerModule.ReadEntries()

    # Filter the entries for the given time range.
    $Entries = [Enumerable]::Where($Entries, [Func[TimerEntry, bool]] {
            param ($TimerEntry)
            return ($Tag -eq "" -or $Tag -eq $TimerEntry.Tag) -and
                ($null -eq $From -or $From -le $TimerEntry.Start) -and
                ($null -eq $To -or $To -ge $TimerEntry.Start)
        }).ToArray()

    # Sums up the duration from all filtered entries.
    $TotalDuration = [timespan]::new(0)
    foreach ($TimerEntry in $Entries) {
        if ($null -ne $TimerEntry.Duration) {
            $TotalDuration += $TimerEntry.Duration
        }
        else {
            # If the entry is still running lets add for how long it is.
            $TotalDuration += ([System.DateTimeOffset]::Now - $TimerEntry.Start)
        }
    }

    Write-Host "Total Duration: $TotalDuration"

    # Return the entries.
    $Entries | Format-Table -Property *, Duration
}

# Removes a entry with the given id.
function Remove-TimerEntry {
    param (
        [int]$Id
    )

    $Entry = $Global:StartTimerModule.RemoveEntry($Id);

    # Prints the removed entry if any.
    $Entry | Format-Table -Property *, Duration
}

# TODO: Implement
function Update-TimerEntry {
    param (
        [int]$Id,
        [string]$Tag,
        [string]$Description,
        [nullable[DateTimeOffset]]$Start,
        [nullable[DateTimeOffset]]$End
    )
}

Set-Alias -Name sat -Value Start-Timer
Set-Alias -Name stt -Value Stop-Timer
Set-Alias -Name gte -Value Get-TimerEntry
Set-Alias -Name rte -Value Remove-TimerEntry

Export-ModuleMember -Function Start-Timer, Stop-Timer, Get-TimerEntry, Remove-TimerEntry
Export-ModuleMember -Alias sat, stt, gte, rte

# Class abstraction for the publisher.
class TimeTrackerPublisher {
    # Publishes the given Entry and return if the publish process was successful or not.
    [bool]Publish([TimerEntry]$TimerEntry) {
        return $false;
    }
}

# Class that represents a entry for the timer tracker.
class TimerEntry {
    [int]$Id
    [string]$Tag
    [string]$Description
    [DateTimeOffset]$Start
    # Possible null end if the entry is still in progress.
    [nullable[DateTimeOffset]]$End
    [bool]$Published

    # Duration does not need to be serialized. So it is hidden.
    hidden [nullable[timespan]]$Duration

    TimerEntry([int]$Id, [string]$Tag, [string]$Description) {
        $this.Id = $Id;
        $this.Tag = $Tag;
        $this.Description = $Description;
        $this.Start = Get-Date;
        $this.End = $null;
        $this.Published = $false

        $this.Duration = $null
    }

    # Construtor for when loading the entry from file.
    TimerEntry([PSCustomObject]$Other) {
        $this.Id = [int]::Parse($Other.Id)
        $this.Tag = $Other.Tag
        $this.Description = $Other.Description
        $this.Start = [DateTimeOffset]::Parse($Other.Start)

        # Process the end field for in progress entries.
        if ($null -ne $Other.End -and $Other.End -ne "") {
            $this.End = [DateTimeOffset]::Parse($Other.End)
            $this.Duration = $this.End - $this.Start
        }
        else {
            $this.End = $null
            $this.Duration = $null
        }
        $this.Published = [bool]::Parse($Other.Published)
    }

    Stop() {
        $this.End = Get-Date
        $this.Duration = $this.End - $this.Start
    }
}

# Module handler.
class StartTimerModule {
    [string]$EntriesSaveFilePath

    StartTimerModule([string]$EntriesSaveFilePath) {
        $this.EntriesSaveFilePath = $EntriesSaveFilePath
    }

    # Read the entries from the persistence file.
    [List[TimerEntry]]ReadEntries() {
        if (Test-Path -Path $this.EntriesSaveFilePath) {
            return Import-Csv -Path $this.EntriesSaveFilePath
        }

        return [List[TimerEntry]]::new()
    }

    # Writes the entries into the persistence file.
    WriteEntries([List[TimerEntry]]$Entries) {
        $Entries | Export-Csv -Path $this.EntriesSaveFilePath
    }

    # Starts a new timer and stops if theres already one in progress.
    [TimerEntry]StartTimer([string]$Tag, [string]$Description) {
        $this.StopTimer()

        $Entries = $this.ReadEntries();

        # Increment the id based on the last entry.
        $Id = $Entries.Count -eq 0 ? 1 : $Entries[$Entries.Count - 1].Id + 1
        $Entries.Add([TimerEntry]::new($Id, $Tag, $Description))

        $this.WriteEntries($Entries);
        return $Entries[$Entries.Count - 1]
    }

    # Stops the latest entry in progress. Return it if any is found.
    [TimerEntry]StopTimer() {
        $Entries = $this.ReadEntries()
        if ($Entries.Count -eq 0) {
            return $null
        }

        $LastEntry = $Entries[$Entries.Count - 1]
        if ($null -ne $LastEntry.End) {
            return $null
        }

        $LastEntry.Stop()

        $this.WriteEntries($Entries)
        return $LastEntry
    }

    # Removes the entry with the given id. Returns the entry if found.
    [TimerEntry]RemoveEntry([int]$Id) {
        $Entries = $this.ReadEntries()
        
        # Looks for the entry on the entries list.
        $Entry = [Enumerable]::FirstOrDefault($Entries, [Func[TimerEntry, bool]] {
                param ($TimerEntry)
                return $Id -eq $TimerEntry.Id
            })

        $Entries.Remove($Entry)
        $this.WriteEntries($Entries)

        return $Entry
    }

    # Publishes the entries that ain't yet published to the given publisher.
    # A list with the entries that was tried to publish is returned.
    [List[TimerEntry]]PublishEntries([TimeTrackerPublisher]$Publisher) {
        $Entries = $this.ReadEntries()
        
        if ($Entries.Count -eq 0) {
            return $Entries
        }

        # Select only the entries that wasn't published and thats not currently in progress.
        $FilteredEnties = [Enumerable]::Where($Entries, [Func[TimerEntry, bool]] {
            param ($TimerEntry)
            return $null -ne $TimerEntry.End -and -not $TimerEntry.Published
        })
        
        # Copies the Enumerable into a List.
        $PublishedEntries = [List[TimerEntry]]::new($FilteredEnties)

        foreach ($Entry in $PublishedEntries) {
            $Entry.Published = $Publisher.Publish($Entry)
        }

        $this.WriteEntries($Entries)

        return $PublishedEntries
    }
}
