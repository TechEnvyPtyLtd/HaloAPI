Function New-HaloTicket {
    <#
        .SYNOPSIS
            Creates one or more tickets via the Halo API.
        .DESCRIPTION
            Function to send a ticket creation request to the Halo API
        .OUTPUTS
            Outputs an object containing the response from the web request.
    #>
    [CmdletBinding( SupportsShouldProcess = $True )]
    [OutputType([Object[]])]
    Param (
        # Object or array of objects containing properties and values used to create one or more new tickets.
        [Parameter( Mandatory = $True )]
        [Object[]]$Ticket,
        # Return all results when letting Halo batch process.
        [Parameter()]
        [Switch]$ReturnAll
    )
    Invoke-HaloPreFlightCheck
    try {
        $CommandName = $MyInvocation.InvocationName
        $Parameters = (Get-Command -Name $CommandName).Parameters
        # Workaround to prevent the query string processor from adding an 'actionid=' parameter by removing it from the set parameters.
        if ($ActionID) {
            $Parameters.Remove('Ticket') | Out-Null
        }
        $QSCollection = New-HaloQuery -CommandName $CommandName -Parameters $Parameters
        if ($PSCmdlet.ShouldProcess($Ticket -is [Array] ? 'Tickets' : 'Ticket', 'Create')) {
            if ($Batch -and $Ticket -is [Array]) {
                $BatchResults = [System.Collections.Concurrent.ConcurrentBag[PSObject]]::New()
                $Ticket | ForEach-Object -Parallel {
                    Import-Module 'X:\Development\Repositories\MJCO\HaloAPI\HaloAPI.psm1'
                    Write-Debug $Using:HAPIConnectionInformation.AuthScopes
                    $HaloConnectionParams = @{
                        URL = $Using:HAPIConnectionInformation.URL
                        ClientID = $Using:HAPIConnectionInformation.ClientID
                        ClientSecret = $Using:HAPIConnectionInformation.ClientSecret
                        Scopes = $Using:HAPIConnectionInformation.AuthScopes
                        Tenant = $Using:HAPIConnectionInformation.Tenant
                        AdditionalHeaders = $Using:HAPIConnectionInformation.AdditionalHeaders
                    }
                    if ($DebugPreference -eq 'Continue') {
                        $HaloConnectionParams.Debug = $True
                    }
                    if ($VerbosePreference -eq 'Continue') {
                        $HaloConnectionParams.Verbose = $True
                    }
                    Connect-HaloAPI @HaloConnectionParams
                    $LocalBatchResults = $using:BatchResults
                    [PSCustomObject]$Ticket = New-HaloTicket -Ticket $_
                    $LocalBatchResults.Add($Ticket)
                }
                Return $BatchResults
            } else {
                New-HaloPOSTRequest -Object $Ticket -Endpoint 'tickets'
            }
            
        }
    } catch {
        New-HaloError -ErrorRecord $_
    }
}