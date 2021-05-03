$ErrorActionPreference = 'Stop'

function not-exist { -not (Test-Path $args) }
Set-Alias !exists not-exist -Option "Constant, AllScope"
Set-Alias exists Test-Path -Option "Constant, AllScope"

function exec {
    [CmdletBinding()]
    param([Parameter(Position=0,Mandatory=1)][scriptblock]$cmd)
    Write-Host "$cmd"
    # https://stackoverflow.com/q/2095088
    $ErrorActionPreference = 'Continue'
    & $cmd
    $ErrorActionPreference = 'Stop'
    if ($lastexitcode -ne 0) {
        throw ("ERROR exit code $lastexitcode")
    }
}

function HasCondaEnv($name) {
    $env_base = conda info --base
    $env_dir = "$env_base/envs/$name"
    return (Test-Path $env_dir)
}

if (!$env:PYTHON_VERSION) {
    throw "PYTHON_VERSION env var missing, must be x.y"
}
if ($env:PYTHON_ARCH -ne '32' -and $env:PYTHON_ARCH -ne '64') {
    throw "PYTHON_ARCH env var must be 32 or 64"
}
if (!$env:NUMPY_VERSION) {
    throw "NUMPY_VERSION env var missing"
}

Get-ChildItem env:

$env:CONDA_ROOT = $pwd.Path + "\external\miniconda_$env:PYTHON_ARCH"
& $PSScriptRoot\install-miniconda.ps1

& $env:CONDA_ROOT\shell\condabin\conda-hook.ps1

if (-not (HasCondaEnv pyenv_build_$env:PYTHON_VERSION)) {
    exec { conda update --yes -n base -c defaults conda }
    exec { conda create --yes --name pyenv_build_$env:PYTHON_VERSION python=$env:PYTHON_VERSION numpy=$env:NUMPY_VERSION --force }
}
exec { conda activate pyenv_build_$env:PYTHON_VERSION }

# Check that we have the expected version and architecture for Python
exec { python --version }
exec { python -c "import struct; assert struct.calcsize('P') * 8 == $env:PYTHON_ARCH" }
exec { python -c "import sys; print(sys.prefix)" }

# output what's installed
exec { python -m pip freeze }

# Build the compiled extension.
# -u disables output buffering which caused intermixing of lines
# when the external tools were started  
exec { python -u setup.py bdist_wheel }
