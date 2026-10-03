param(
    [Parameter(Mandatory = $true)][string]$Repository,
    [string]$RecoveryFile = (Join-Path $env:USERPROFILE '.wagz-private/android/signing-recovery.json')
)
$ErrorActionPreference = 'Stop'
if ($Repository -notmatch '^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$') { throw 'Use the exact owner/repository name.' }
$recovery = Get-Content -LiteralPath $RecoveryFile -Raw | ConvertFrom-Json
if ($recovery.applicationId -ne 'hr.wagz.wagz_mobile') { throw 'Signing backup belongs to another app.' }
$secrets = @{
    WAGZ_ANDROID_KEYSTORE_BASE64 = [Convert]::ToBase64String([IO.File]::ReadAllBytes($recovery.storeFile))
    WAGZ_ANDROID_KEYSTORE_PASSWORD = $recovery.storePassword
    WAGZ_ANDROID_KEY_ALIAS = $recovery.keyAlias
    WAGZ_ANDROID_KEY_PASSWORD = $recovery.keyPassword
}
foreach ($name in $secrets.Keys) {
    # Standard input keeps credentials out of command arguments and console output.
    $secrets[$name] | gh secret set $name --repo $Repository
    if ($LASTEXITCODE -ne 0) { throw "Could not provision $name. Retry before running a signed release workflow." }
    Write-Output "$name configured."
}
