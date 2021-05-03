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

$PYVER = ($env:PYTHON_VERSION).Replace('.', '')

Get-ChildItem env:

$env:CONDA_ROOT = $pwd.Path + "\external\miniconda_$env:PYTHON_ARCH"
& $PSScriptRoot\install-miniconda.ps1

& $env:CONDA_ROOT\shell\condabin\conda-hook.ps1

# Import test on a minimal environment
# (to catch DLL issues)
if (-not (HasCondaEnv pyenv_minimal_$env:PYTHON_VERSION)) {
    exec { conda create --yes --name pyenv_minimal_$env:PYTHON_VERSION python=$env:PYTHON_VERSION --force }
}
exec { conda activate pyenv_minimal_$env:PYTHON_VERSION }

# Avoid using in-source package
New-Item -Force -ItemType directory tmp | out-null
cd tmp

python -m pip uninstall -y pyvirtualcam
ls ..\dist\*cp${PYVER}*win*.whl | % { exec { python -m pip install $_ } }
exec { python -c "import pyvirtualcam" }

# Necessary to avoid bug when switching to test env.
exec { conda deactivate }

# Unit tests
if (-not (HasCondaEnv pyenv_test_$env:PYTHON_VERSION)) {
    exec { conda create --yes --name pyenv_test_$env:PYTHON_VERSION python=$env:PYTHON_VERSION numpy --force }
}   
exec { conda activate pyenv_test_$env:PYTHON_VERSION }

# Check that we have the expected version and architecture for Python
exec { python --version }
exec { python -c "import struct; assert struct.calcsize('P') * 8 == $env:PYTHON_ARCH" }
exec { python -c "import sys; print(sys.prefix)" }

# Install test helper package
Push-Location ../test/win-dshow-capture
exec { python -u setup.py bdist_wheel }
python -m pip uninstall -y pyvirtualcam_win_dshow_capture
ls dist\*.whl | % { exec { python -m pip install $_ } }
Pop-Location

# output what's installed
exec { python -m pip freeze }

python -m pip uninstall -y pyvirtualcam
ls ..\dist\*cp${PYVER}*win*.whl | % { exec { python -m pip install $_ } }
exec { python -m pip install -r ..\dev-requirements.txt }
exec { pytest -v -s ../test }
cd ..
