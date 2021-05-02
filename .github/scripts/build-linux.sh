#!/bin/bash
set -e -x

cd /io

source .github/scripts/retry.sh

# List python versions
ls /opt/python

if [ $PYTHON_VERSION == "3.6" ]; then
    PYBIN="/opt/python/cp36-cp36m/bin"
elif [ $PYTHON_VERSION == "3.7" ]; then
    PYBIN="/opt/python/cp37-cp37m/bin"
elif [ $PYTHON_VERSION == "3.8" ]; then
    PYBIN="/opt/python/cp38-cp38/bin"
elif [ $PYTHON_VERSION == "3.9" ]; then
    PYBIN="/opt/python/cp39-cp39/bin"
else
    echo "Unsupported Python version $PYTHON_VERSION"
    exit 1
fi

# install compile-time dependencies
retry ${PYBIN}/pip install numpy==${NUMPY_VERSION}

# List installed packages
${PYBIN}/pip freeze

# Build pyvirtualcam wheel
export LDFLAGS="-Wl,--strip-debug"
${PYBIN}/python setup.py bdist_wheel --dist-dir dist-tmp

# Bundle external shared libraries into wheel
mkdir dist
auditwheel repair dist-tmp/pyvirtualcam*.whl -w dist
ls -al dist
