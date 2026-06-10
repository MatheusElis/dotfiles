# Bootstrap script for Windows (PowerShell)
# Usage: irm <url> | iex  OR  .\bootstrap-windows.ps1
# NOTE: Does NOT require admin privileges

Write-Host ""
Write-Host "╔══════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║   comuvim bootstrap — Windows            ║" -ForegroundColor Cyan
Write-Host "╚══════════════════════════════════════════╝" -ForegroundColor Cyan

$ErrorActionPreference = "Stop"

# --- 1. Install mise ---
Write-Host ""
Write-Host "🔧 Installing mise..." -ForegroundColor Yellow

$miseDir = "$env:LOCALAPPDATA\mise\bin"
$miseExe = "$miseDir\mise.exe"

if (Test-Path $miseExe) {
    Write-Host "  mise already installed: $(& $miseExe --version)"
} else {
    Write-Host "  Downloading mise from GitHub..."
    $releases = Invoke-RestMethod "https://api.github.com/repos/jdx/mise/releases/latest"
    $zipAsset = $releases.assets | Where-Object { $_.name -like "*windows-x64.zip" } | Select-Object -First 1
    $zipUrl = $zipAsset.browser_download_url
    $zipPath = "$env:TEMP\mise.zip"

    Invoke-WebRequest -Uri $zipUrl -OutFile $zipPath -UseBasicParsing
    if (!(Test-Path $miseDir)) { New-Item -ItemType Directory -Path $miseDir -Force | Out-Null }
    
    $tempExtract = "$env:TEMP\mise_extract"
    Expand-Archive -Path $zipPath -DestinationPath $tempExtract -Force
    
    # Find and move binaries
    $miseBin = Get-ChildItem -Path $tempExtract -Recurse -Filter "mise.exe" | Select-Object -First 1
    $miseShim = Get-ChildItem -Path $tempExtract -Recurse -Filter "mise-shim.exe" -ErrorAction SilentlyContinue | Select-Object -First 1
    
    Copy-Item $miseBin.FullName "$miseDir\mise.exe" -Force
    if ($miseShim) { Copy-Item $miseShim.FullName "$miseDir\mise-shim.exe" -Force }
    
    Remove-Item $zipPath -Force -ErrorAction SilentlyContinue
    Remove-Item $tempExtract -Recurse -Force -ErrorAction SilentlyContinue

    # Add to user PATH
    $currentPath = [Environment]::GetEnvironmentVariable("PATH", "User")
    if ($currentPath -notlike "*$miseDir*") {
        [Environment]::SetEnvironmentVariable("PATH", "$miseDir;$currentPath", "User")
    }
    $env:PATH = "$miseDir;$env:PATH"
    
    Write-Host "  mise installed: $(& $miseExe --version)"
}

# --- 2. Setup PowerShell profile ---
Write-Host ""
Write-Host "⚙️  Configuring PowerShell profile..." -ForegroundColor Yellow

$profileDir = Split-Path $PROFILE
if (!(Test-Path $profileDir)) { New-Item -ItemType Directory -Path $profileDir -Force | Out-Null }

$miseActivation = 'mise activate pwsh | Out-String | Invoke-Expression'
if (!(Test-Path $PROFILE) -or !(Select-String -Path $PROFILE -Pattern "mise activate" -Quiet)) {
    Add-Content -Path $PROFILE -Value "`n# mise-en-place (version manager)`n$miseActivation"
    Write-Host "  Added mise activation to $PROFILE"
} else {
    Write-Host "  Profile already configured"
}

# --- 3. Configure mise global tools ---
Write-Host ""
Write-Host "⚙️  Configuring mise tools..." -ForegroundColor Yellow

$miseConfigDir = "$env:USERPROFILE\.config\mise"
if (!(Test-Path $miseConfigDir)) { New-Item -ItemType Directory -Path $miseConfigDir -Force | Out-Null }

$miseConfig = @'
[tools]
python = "3.13"
node = "latest"
go = "latest"
java = "adoptopenjdk-21"
neovim = "latest"
zig = "latest"
'@

Set-Content -Path "$miseConfigDir\config.toml" -Value $miseConfig
Write-Host "  Config written to $miseConfigDir\config.toml"

# --- 4. Install all tools ---
Write-Host ""
Write-Host "📥 Installing tools via mise..." -ForegroundColor Yellow
& $miseExe install

# --- 5. Verify installations ---
Write-Host ""
Write-Host "✅ Verifying installations..." -ForegroundColor Green
& $miseExe exec -- python --version
& $miseExe exec -- node --version
& $miseExe exec -- go version
& $miseExe exec -- nvim --version | Select-Object -First 1
& $miseExe exec -- zig version

# --- 6. Link Neovim config ---
Write-Host ""
Write-Host "📂 Setting up Neovim config..." -ForegroundColor Yellow

$nvimConfigDir = "$env:LOCALAPPDATA\nvim"
if (Test-Path $nvimConfigDir) {
    Write-Host "  Neovim config already exists at $nvimConfigDir"
} else {
    Write-Host "  ⚠️  No nvim config found at $nvimConfigDir"
    Write-Host "  Copy or clone your dotfiles nvim config there."
}

# --- 7. Install Neovim plugins ---
Write-Host ""
Write-Host "🔌 Installing Neovim plugins..." -ForegroundColor Yellow
& $miseExe exec -- nvim --headless "+Lazy! sync" +qa 2>$null

# --- 8. Install Mason tools ---
Write-Host ""
Write-Host "🛠️  Installing Mason tools..." -ForegroundColor Yellow
& $miseExe exec -- nvim --headless "+MasonToolsInstallSync" +qa 2>$null

Write-Host ""
Write-Host "╔══════════════════════════════════════════╗" -ForegroundColor Green
Write-Host "║   ✅ Bootstrap complete!                  ║" -ForegroundColor Green
Write-Host "║   Restart your terminal to activate.     ║" -ForegroundColor Green
Write-Host "╚══════════════════════════════════════════╝" -ForegroundColor Green
