param(
    [string]$PrivateDirectory = (Join-Path $env:USERPROFILE '.wagz-private/android'),
    [string]$Keytool = 'C:/Program Files/Android/Android Studio/jbr/bin/keytool.exe'
)
$ErrorActionPreference = 'Stop'
$mobileDirectory = Split-Path $PSScriptRoot -Parent
$propertiesPath = Join-Path $mobileDirectory 'android/key.properties'
$keyPath = Join-Path $PrivateDirectory 'wagz-upload.jks'
$recoveryPath = Join-Path $PrivateDirectory 'signing-recovery.json'
if ((Test-Path -LiteralPath $keyPath) -or (Test-Path -LiteralPath $recoveryPath) -or (Test-Path -LiteralPath $propertiesPath)) {
    throw 'Signing material already exists. Reuse and back it up; do not replace the app identity.'
}
if (!(Test-Path -LiteralPath $Keytool)) { throw 'Set -Keytool to the Android JDK keytool executable.' }

# The directory and every inherited file are accessible only to this Windows user and SYSTEM.
New-Item -ItemType Directory -Force -Path $PrivateDirectory | Out-Null
$identity = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
$acl = Get-Acl -LiteralPath $PrivateDirectory
$acl.SetAccessRuleProtection($true, $false)
foreach ($principal in @($identity, 'NT AUTHORITY\SYSTEM')) {
    $acl.AddAccessRule([System.Security.AccessControl.FileSystemAccessRule]::new($principal, 'FullControl', 'ContainerInherit,ObjectInherit', 'None', 'Allow'))
}
Set-Acl -LiteralPath $PrivateDirectory -AclObject $acl
$bytes = New-Object byte[] 32
[System.Security.Cryptography.RandomNumberGenerator]::Fill($bytes)
$password = [Convert]::ToHexString($bytes).ToLowerInvariant()
$env:WAGZ_SIGNING_PASSWORD = $password
try {
    & $Keytool -genkeypair -noprompt -keystore $keyPath -storetype JKS -keyalg RSA -keysize 3072 -validity 10000 -alias wagz-upload -dname 'CN=WagZ, OU=Mobile, O=WagZ, L=Osijek, C=HR' -storepass:env WAGZ_SIGNING_PASSWORD -keypass:env WAGZ_SIGNING_PASSWORD
    if ($LASTEXITCODE -ne 0) { throw 'Android signing key generation failed.' }
    $recovery = @{ applicationId = 'hr.wagz.wagz_mobile'; keyAlias = 'wagz-upload'; storePassword = $password; keyPassword = $password; storeFile = $keyPath; createdAt = [DateTime]::UtcNow.ToString('o') }
    [IO.File]::WriteAllText($recoveryPath, ($recovery | ConvertTo-Json))
    $properties = "storeFile=$($keyPath.Replace('\', '/'))`nkeyAlias=wagz-upload`nstorePassword=$password`nkeyPassword=$password`n"
    [IO.File]::WriteAllText($propertiesPath, $properties)
    $fileAcl = Get-Acl -LiteralPath $propertiesPath
    $fileAcl.SetAccessRuleProtection($true, $false)
    foreach ($principal in @($identity, 'NT AUTHORITY\SYSTEM')) {
        $fileAcl.AddAccessRule([System.Security.AccessControl.FileSystemAccessRule]::new($principal, 'FullControl', 'Allow'))
    }
    Set-Acl -LiteralPath $propertiesPath -AclObject $fileAcl
    $backupPath = Join-Path $PrivateDirectory ('wagz-signing-recovery-' + [DateTime]::UtcNow.ToString('yyyyMMdd-HHmmss') + '.zip')
    Compress-Archive -LiteralPath $keyPath, $recoveryPath -DestinationPath $backupPath
    Write-Output "Signing configured. Private owner backup: $backupPath"
    Write-Output 'Copy that private backup to owner-controlled offline storage; do not attach it to a public release.'
} finally {
    Remove-Item Env:WAGZ_SIGNING_PASSWORD -ErrorAction SilentlyContinue
    $password = $null
}
