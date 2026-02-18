<#
This is an example PowerShell script to show how to customize an App Service Managed Instance to perform additional configuration after it has been provisioned.
In this example, the script creates a registry key with a string value, creates a JSON configuration file on the C: drive, and installs fonts from the current directory and subdirectories to the Windows Fonts folder.
You can RDP via Azure Bastion onto one of the instances in the App Service Managed Instance to see the results after deployment.
#>

# Create a registry key with a string value
Write-Host "Creating registry key..."

$registryPath = "HKLM:\SOFTWARE\MyApp2"
$valueName    = "SettingFromInstallScript"
$valueData    = "ValueFromInstallScript"
$valueType    = "String"

if (-not (Test-Path $registryPath)) {
  New-Item -Path $registryPath -Force | Out-Null
}

Set-ItemProperty -Path $registryPath -Name $valueName -Value $valueData -Type $valueType

# Create a file on the C: drive with some sample content
Write-Host "Creating file on C: drive..."

$filePath = "C:\MyAppConfig.json"
$content = ConvertTo-Json -InputObject @{ Setting1 = $true; Setting2 = "Value2"; Setting3 = 42 } -Depth 3
Set-Content -Path $filePath -Value $content -Force

# Install fonts from the current directory and subdirectories
Write-Host "Install fonts..."

Get-ChildItem -Recurse -Include *.ttf, *.otf | ForEach-Object {
    $FontFullName = $_.FullName
    $FontName = $_.BaseName + " (TrueType)"
    $Destination = "$env:windir\Fonts\$($_.Name)"

    Write-Host "Installing font: $($_.Name)"
    Copy-Item $FontFullName -Destination $Destination -Force
    New-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts" -Name $FontName -PropertyType String -Value $_.Name -Force | Out-Null
}

Write-Host "Font installation completed." -ForegroundColor Green
