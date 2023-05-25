#Created by Khalil Hasanzade
param (
    [Parameter(Mandatory=$true)]
    [string]$SiteName,

    [Parameter(Mandatory=$true)]
    [string]$PhysicalPath,

    [Parameter(Mandatory=$true)]
    [string]$DomainName,

    [Parameter(Mandatory=$true)]
    [string]$EmailAddress
)
# Install the required IIS features
$features = "Web-WebServer", "Web-Scripting-Tools", "Web-Mgmt-Tools"
Install-WindowsFeature -Name $features

# Import the WebAdministration module
Import-Module WebAdministration

# Check if the website already exists
$existingWebsite = Get-Website -Name $SiteName
if ($existingWebsite) {
    # Website already exists, stop and remove it
    Stop-Website -Name $SiteName
    Remove-Website -Name $SiteName -Confirm:$false
}

# Create a new IIS website
$website = New-Website -Name $SiteName -PhysicalPath $PhysicalPath -Port 80 -HostHeader $DomainName

# Start the website
Start-Website -Name $SiteName

# Download and extract win-acme
$winAcmeUrl = 'https://github.com/win-acme/win-acme/releases/download/v2.2.4.1500/win-acme.v2.2.4.1500.x64.trimmed.zip'
$winAcmePath = Join-Path -Path $env:TEMP -ChildPath 'win-acme'
$winAcmeZipPath = Join-Path -Path $winAcmePath -ChildPath 'win-acme.zip'

# Download win-acme using Invoke-WebRequest
Invoke-WebRequest -Uri $winAcmeUrl -OutFile $winAcmeZipPath

# Extract win-acme
Expand-Archive -Path $winAcmeZipPath -DestinationPath $winAcmePath -Force

# Set the path to win-acme
$winAcmeExePath = Join-Path -Path $winAcmePath -ChildPath 'wacs.exe'

# Check if the certificate already exists
$certStore = "Cert:\LocalMachine\WebHosting"
$existingCertificate = Get-ChildItem -Path $certStore | Where-Object { $_.Subject -like "*$DomainName*" }

if ($existingCertificate) {
    Write-Host "Existing certificate found for '$DomainName'."
    $thumbprint = $existingCertificate.Thumbprint
}
else {
    # Create Let's Encrypt SSL certificate
    $siteId = $website.Id
    & $winAcmeExePath --target manual --host $DomainName --installationsiteid $siteId --accepttos  --emailaddress $EmailAddress

    # Get the thumbprint of the newly created certificate
    $thumbprint = (Get-ChildItem -Path $certStore | Where-Object { $_.Subject -like "*$DomainName*" }).Thumbprint
}

# Stop the website before configuring the SSL binding
Stop-Website -Name $SiteName

Write-Output $thumbprint

# Configure the SSL binding
cd IIS:\
New-WebBinding -Name $SiteName -IP "*" -Port 443 -Protocol https

cd IIS:\SslBindings
get-item cert:\localmachine\WebHosting\$thumbprint | new-item 0.0.0.0!443

# Start the website again
Start-Website -Name $SiteName

Write-Host "IIS website '$SiteName' created successfully with Let's Encrypt SSL certificate."
#Created by Khalil Hasanzade
