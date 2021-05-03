#!/bin/bash
set -e -x

source .github/scripts/retry.sh

git clone https://github.com/matthew-brett/multibuild.git
pushd multibuild
set +x # reduce noise
source osx_utils.sh
PYTHON_OSX_VER=$(macpython_sdk_for_version $PYTHON_VERSION)
get_macpython_environment $PYTHON_VERSION venv $PYTHON_OSX_VER
source venv/bin/activate
set -x
popd

# Install pyvirtualcam
pip install dist/pyvirtualcam*cp${PYVER}*macosx*.whl

# Test installed pyvirtualcam
retry pip install -r dev-requirements.txt
mkdir tmp
pushd tmp
python -u -m pytest -v -s ../test
popd
