param
(
    [Parameter(Mandatory=$True,
    ValueFromPipeline=$True,
    ValueFromPipelineByPropertyName=$True,
    HelpMessage='-userName is required.  This should be the logon ID used in Tenable.SC.')]
    [string]$userName,
    [Parameter(Mandatory=$True,
    ValueFromPipeline=$True,
    ValueFromPipelineByPropertyName=$True,
    HelpMessage='-accessKey is required.  API Access Key')]
    [string]$accessKey,
    [Parameter(Mandatory=$True,
    ValueFromPipeline=$True,
    ValueFromPipelineByPropertyName=$True,
    HelpMessage='-secretKey is required.  API Secret Key')]
    [string]$secretKey,
    [Parameter(Mandatory=$True,
    ValueFromPipeline=$True,
    ValueFromPipelineByPropertyName=$True,
    HelpMessage='-baseURL is required.  The URL of your Tenable.SC server.  Example: https://tsc.example.com')]
    [string]$baseURL
)

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

if (-Not ("TrustAllCertsPolicy" -as [type]))
{
add-type @"
    using System.Net;
    using System.Security.Cryptography.X509Certificates;
    public class TrustAllCertsPolicy : ICertificatePolicy
    {
        public bool CheckValidationResult
        (
            ServicePoint srvPoint, X509Certificate certificate,
            WebRequest request, int certificateProblem
        )
        {
            return true;
        }
    }
"@


    [System.Net.ServicePointManager]::CertificatePolicy = New-Object TrustAllCertsPolicy
}

$Headers = @{
    "x-apikey" = "accesskey=$accessKey;secretkey=$secretKey"
}

#$*$*$*$*$*$*$*$*$*$*$*$*$*$*$*$*$*$*$*$*$*$*$*$*$*$*$*$
# Functions
#$*$*$*$*$*$*$*$*$*$*$*$*$*$*$*$*$*$*$*$*$*$*$*$*$*$*$*$

Function Get-TscUserObj
{
    <#
    .SYNOPSIS
    Given the Tenable.SC user name, retures the user record for the Tenable.SC account
    .DESCRIPTION
    Uses the T.SC API to pull all users.  Then searches the JSON object for a user account matching the 'username' field.
    .EXAMPLE
    EX. Get-IPfromName -URL https://tsc.example.com -aKey lkajsd09023f -sKey 08ajlsdkfj03 -uName jason
    .PARAMETER URL
    Base URL of the Tenable.SC instance.
    .PARAMETER aKey
    API Access Key.
    .PARAMETER sKey
    API Secret Key.
    .PARAMETER uName
    User name to search for.
    #>
    [cmdletbinding()]
    Param (
        [Parameter(Mandatory=$True,
        ValueFromPipeline=$True,
        ValueFromPipelineByPropertyName=$True,
        HelpMessage='Base URL of the Tenable.SC instance.')]
        [string]$URL,
        [Parameter(Mandatory=$True,
        ValueFromPipeline=$True,
        ValueFromPipelineByPropertyName=$True,
        HelpMessage='API Access Key')]
        [string]$aKey,
        [Parameter(Mandatory=$True,
        ValueFromPipeline=$True,
        ValueFromPipelineByPropertyName=$True,
        HelpMessage='API Secret Key.')]
        [string]$sKey,
        [Parameter(Mandatory=$True,
        ValueFromPipeline=$True,
        ValueFromPipelineByPropertyName=$True,
        HelpMessage='User name to search for.')]
        [string]$uName
    )

    $JsonFromResponse = $null
    $WebRequestContent = $null

    $Headers = @{
        "x-apikey" = "accesskey=$aKey;secretkey=$sKey"
    }

    try
    {
        $WebRequestContent = Invoke-WebRequest -Uri "$URL/rest/user" -Headers $Headers -Method Get
    }
    catch
    {
        $streamReader = [System.IO.StreamReader]::new($_.Exception.Response.GetResponseStream())
        $ErrResp = $streamReader.ReadToEnd() | ConvertFrom-Json
        $streamReader.Close()
    }

    if ($ErrResp -or ($WebRequestContent -eq $null))
    {
        Write-Host "There was an error!" -ForegroundColor Red
        Write-Host $ErrResp -ForegroundColor Yellow
        $JsonFromResponse = $null
    }
    else
    {
        $JsonFromResponse = $WebRequestContent.Content | ConvertFrom-Json
    }

    if ($JsonFromResponse)
    {
        $userRecord = $JsonFromResponse.response | where {$_.username -eq $uName}
        Return $userRecord
    }
    else
    {
        if ($JsonFromResponse.error_msg)
        {
            Write-Host $JsonFromResponse.error_msg -ForegroundColor Yellow
            Return $null
        }
        else
        {
            Write-Host "Error getting user records from T.SC" -ForegroundColor Yellow
            Return $null
        }
    }
}

Function Add-TscAssignedTicketQuery
{
    <#
    .SYNOPSIS
    Given the Tenable.SC user ID, create a Query in Tenable.SC that returns all tickets assigned to that user within the last hour
    .EXAMPLE
    EX. Get-IPfromName -URL https://tsc.example.com -aKey lkajsd09023f -sKey 08ajlsdkfj03 -uName jason
    .PARAMETER URL
    Base URL of the Tenable.SC instance.
    .PARAMETER aKey
    API Access Key.
    .PARAMETER sKey
    API Secret Key.
    .PARAMETER uObject
    User object returned from Get-TscUserObj function.
    #>
    [cmdletbinding()]
    Param (
        [Parameter(Mandatory=$True,
        ValueFromPipeline=$True,
        ValueFromPipelineByPropertyName=$True,
        HelpMessage='Base URL of the Tenable.SC instance.')]
        [string]$URL,
        [Parameter(Mandatory=$True,
        ValueFromPipeline=$True,
        ValueFromPipelineByPropertyName=$True,
        HelpMessage='API Access Key')]
        [string]$aKey,
        [Parameter(Mandatory=$True,
        ValueFromPipeline=$True,
        ValueFromPipelineByPropertyName=$True,
        HelpMessage='API Secret Key.')]
        [string]$sKey,
        [Parameter(Mandatory=$True,
        ValueFromPipeline=$True,
        ValueFromPipelineByPropertyName=$True,
        HelpMessage='User object returned from Get-TscUserObj function.')]
        [psobject[]]$uObject
    )

    $Json = "
    {
        `"name`": `"$($uObject.firstname) $($uObject.lastname) Assignee - 1 hr`",
        `"tool`": `"listtickets`",
        `"type`": `"ticket`",                
        `"filters`": [
            {
                `"filterName`": `"assignee`",
                `"operator`": `"=`",
                `"value`": [
                    {
                        `"id`": `"$($uObject.id)`"
                    }
                ]
            },
            {
                `"filterName`": `"assignedTimeFrame`",
                `"operator`": `"=`",
                `"value`": `"h`"
            }
        ]
    }"

    $JsonFromResponse = $null
    $WebRequestContent = $null

    $Headers = @{
        "x-apikey" = "accesskey=$aKey;secretkey=$sKey"
    }

    try
    {
        $WebRequestContent = Invoke-WebRequest -Uri "$URL/rest/query" -Headers $Headers -Method Post -Body $Json -ContentType "application/json"
    }
    catch
    {
        $streamReader = [System.IO.StreamReader]::new($_.Exception.Response.GetResponseStream())
        $ErrResp = $streamReader.ReadToEnd() | ConvertFrom-Json
        $streamReader.Close()
    }

    if ($ErrResp -or ($WebRequestContent -eq $null))
    {
        Write-Host "There was an error!" -ForegroundColor Red
        Write-Host $ErrResp -ForegroundColor Yellow
        $JsonFromResponse = $null
    }
    else
    {
        $JsonFromResponse = $WebRequestContent.Content | ConvertFrom-Json
    }

    if ($JsonFromResponse)
    {
        $apiResponse = $JsonFromResponse.response
        Return $apiResponse.id
    }
    else
    {
        if ($JsonFromResponse.error_msg)
        {
            Write-Host $JsonFromResponse.error_msg -ForegroundColor Yellow
            Return $null
        }
        else
        {
            Write-Host "Error creating query." -ForegroundColor Yellow
            Return $null
        }
    }
}

Function Add-TscAssignedTicketAlert
{
    <#
    .SYNOPSIS
    Given the Tenable.SC user ID, create a Query in Tenable.SC that returns all tickets assigned to that user within the last hour
    .EXAMPLE
    EX. Get-IPfromName -URL https://tsc.example.com -aKey lkajsd09023f -sKey 08ajlsdkfj03 -uName jason
    .PARAMETER URL
    Base URL of the Tenable.SC instance.
    .PARAMETER aKey
    API Access Key.
    .PARAMETER sKey
    API Secret Key.
    .PARAMETER uObject
    User object returned from Get-TscUserObj function.
    .PARAMETER qID
    Query ID from the query created by function Add-TscAssignedTicketQuery.
    #>
    [cmdletbinding()]
    Param (
        [Parameter(Mandatory=$True,
        ValueFromPipeline=$True,
        ValueFromPipelineByPropertyName=$True,
        HelpMessage='Base URL of the Tenable.SC instance.')]
        [string]$URL,
        [Parameter(Mandatory=$True,
        ValueFromPipeline=$True,
        ValueFromPipelineByPropertyName=$True,
        HelpMessage='API Access Key')]
        [string]$aKey,
        [Parameter(Mandatory=$True,
        ValueFromPipeline=$True,
        ValueFromPipelineByPropertyName=$True,
        HelpMessage='API Secret Key.')]
        [string]$sKey,
        [Parameter(Mandatory=$True,
        ValueFromPipeline=$True,
        ValueFromPipelineByPropertyName=$True,
        HelpMessage='User object returned from Get-TscUserObj function.')]
        [psobject[]]$uObject,
        [Parameter(Mandatory=$True,
        ValueFromPipeline=$True,
        ValueFromPipelineByPropertyName=$True,
        HelpMessage='Query ID from the query created by function Add-TscAssignedTicketQuery.')]
        [string]$qID
    )

    $icalDate = Get-Date -Format "yyyyMMdd'T'hhmmss"
    $Json = "{
    `"name`": `"$($uObject.firstname) $($uObject.lastname) - Ticket Assigned`",
    `"description`" : `"A ticket has been assigned to $($uObject.firstname) $($uObject.lastname) and an email will be generated`",
    `"query`": {
        `"id`": `"$qID`"
    },
    `"triggerName`": `"listtickets`",
    `"triggerOperator`": `">=`",
    `"triggerValue`": `"1`",
    `"executeOnEveryTrigger`": `"false`",
    `"action`": [
        {
            `"type`": `"email`",
            `"subject`": `"Tenable Ticket has been assigned to you`",
            `"message`": `"<p>Alert <strong>%alertName%</strong> (id #%alertID%) has triggered.</p>\n\n<p>Please visit your Tenable.sc (<a href=\`"%url%\`">%url%</a>) for more information.</p>\n\n<p>This e-mail was automatically generated by Tenable.sc as a result of alert <strong>%alertName%</strong> owned by <strong>%owner%</strong>.</p>\n\n<p>If you do not wish to receive this email, contact the alert owner.</p>`",
            `"addresses`": `"`",
            `"users`": [
                {
                    `"id`": `"$($uObject.id)`"
                }
            ],
            `"includeResults`": `"false`"
        }
    ],
    `"schedule`": {
        `"type`": `"ical`",
        `"start`": `"TZID=America/Chicago:$icalDate`",
        `"repeatRule`": `"FREQ=MINUTELY;INTERVAL=15`"
    }
}"

    $JsonFromResponse = $null
    $WebRequestContent = $null

    $Headers = @{
        "x-apikey" = "accesskey=$aKey;secretkey=$sKey"
    }

    try
    {
        $WebRequestContent = Invoke-WebRequest -Uri "$URL/rest/alert" -Headers $Headers -Method Post -Body $Json -ContentType "application/json"
    }
    catch
    {
        $streamReader = [System.IO.StreamReader]::new($_.Exception.Response.GetResponseStream())
        $ErrResp = $streamReader.ReadToEnd() | ConvertFrom-Json
        $streamReader.Close()
    }

    if ($ErrResp -or ($WebRequestContent -eq $null))
    {
        Write-Host "There was an error!" -ForegroundColor Red
        Write-Host $ErrResp -ForegroundColor Yellow
        $JsonFromResponse = $null
    }
    else
    {
        $JsonFromResponse = $WebRequestContent.Content | ConvertFrom-Json
    }

    if ($JsonFromResponse)
    {
        $apiResponse = $JsonFromResponse.response
        Return $apiResponse.id
    }
    else
    {
        if ($JsonFromResponse.error_msg)
        {
            Write-Host $JsonFromResponse.error_msg -ForegroundColor Yellow
            Return $null
        }
        else
        {
            Write-Host "Error creating alert." -ForegroundColor Yellow
            Return $null
        }
    }
}

#$*$*$*$*$*$*$*$*$*$*$*$*$*$*$*$*$*$*$*$*$*$*$*$*$*$*$*$
# End of Functions
#$*$*$*$*$*$*$*$*$*$*$*$*$*$*$*$*$*$*$*$*$*$*$*$*$*$*$*$

$userObj = Get-TscUserObj -URL $baseURL -aKey $accessKey -sKey $secretKey -uName $userName

if ($userObj)
{
    $queryID = Add-TscAssignedTicketQuery -URL $baseURL -aKey $accessKey -sKey $secretKey -uObject $userObj

    if ($queryID)
    {
        Write-Host "Query created with ID $queryID"
        $alertID = Add-TscAssignedTicketAlert -URL $baseURL -aKey $accessKey -sKey $secretKey -uObject $userObj -qID $queryID
        
        if ($alertID)
        {
            Write-Host "Alert successfully created with ID $alertID"
        }
        else
        {
            Write-Host "Alert could not be created" -ForegroundColor Yellow
        }
    }
    else
    {
        Write-Host "Query could not be created" -ForegroundColor Yellow
    }
}
else
{
    Write-Host "User `"$userName`" could not be queried." -ForegroundColor Yellow
}
