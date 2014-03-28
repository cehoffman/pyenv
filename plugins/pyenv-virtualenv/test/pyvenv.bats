#!/usr/bin/env bats

load test_helper

setup() {
  export PYENV_ROOT="${TMP}/pyenv"
}

stub_pyenv() {
  export PYENV_VERSION="$1"
  stub pyenv-version-name "echo \${PYENV_VERSION}"
  stub pyenv-prefix " : echo '${PYENV_ROOT}/versions/\${PYENV_VERSION}'"
  stub pyenv-hooks "virtualenv : echo"
  stub pyenv-rehash " : echo rehashed"
}

unstub_pyenv() {
  unset PYENV_VERSION
  unstub pyenv-version-name
  unstub pyenv-prefix
  unstub pyenv-hooks
  unstub pyenv-rehash
}

create_executable() {
  mkdir -p "${PYENV_ROOT}/versions/$1/bin"
  touch "${PYENV_ROOT}/versions/$1/bin/$2"
  chmod +x "${PYENV_ROOT}/versions/$1/bin/$2"
}

remove_executable() {
  rm -f "${PYENV_ROOT}/versions/$1/bin/$2"
  
}

@test "use pyvenv if virtualenv is not available" {
  stub_pyenv "3.4.0"
  stub pyenv-which "virtualenv : false" \
                   "pyvenv : echo '${PYENV_ROOT}/versions/bin/pyvenv'"
  stub pyenv-exec "echo PYENV_VERSION=\${PYENV_VERSION} \"\$@\"" \
                  "bin=\"${PYENV_ROOT}/versions/venv/bin\";mkdir -p \"\$bin\";touch \"\$bin/pip3.4\";echo PYENV_VERSION=\${PYENV_VERSION} ensurepip" \
                  "echo pip3.4"
  stub pyenv-prefix "venv : echo '${PYENV_ROOT}/versions/venv'"

  run pyenv-virtualenv venv

  unstub_pyenv
  unstub pyenv-which
  unstub pyenv-exec

  assert_success
  assert_output <<OUT
PYENV_VERSION=3.4.0 pyvenv ${PYENV_ROOT}/versions/venv
PYENV_VERSION=venv ensurepip
rehashed
OUT
  assert [ -e "${PYENV_ROOT}/versions/venv/bin/pip" ]
}

@test "not use pyvenv if virtualenv is available" {
  stub_pyenv "3.4.0"
  stub pyenv-which "virtualenv : echo '${PYENV_ROOT}/versions/bin/virtualenv'" \
                   "pyvenv : echo '${PYENV_ROOT}/versions/bin/pyvenv"
  stub pyenv-exec "echo PYENV_VERSION=\${PYENV_VERSION} \"\$@\""

  run pyenv-virtualenv venv

  unstub_pyenv
  unstub pyenv-which
  unstub pyenv-exec

  assert_success
  assert_output <<OUT
PYENV_VERSION=3.4.0 virtualenv ${PYENV_ROOT}/versions/venv
rehashed
OUT
}

@test "install virtualenv if pyvenv is not avaialble" {
  stub_pyenv "3.2.1"
  stub pyenv-which "virtualenv : false" \
                   "pyvenv : false"
  stub pyenv-exec "echo PYENV_VERSION=\${PYENV_VERSION} \"\$@\"" \
                  "echo PYENV_VERSION=\${PYENV_VERSION} \"\$@\""

  run pyenv-virtualenv venv

  unstub_pyenv
  unstub pyenv-which
  unstub pyenv-exec

  assert_success
  assert_output <<OUT
PYENV_VERSION=3.2.1 pip install virtualenv
PYENV_VERSION=3.2.1 virtualenv ${PYENV_ROOT}/versions/venv
rehashed
OUT
}

@test "install virtualenv with unsetting troublesome pip options" {
  stub_pyenv "3.2.1"
  stub pyenv-which "virtualenv : false" \
                   "pyvenv : false"
  stub pyenv-exec "echo PIP_REQUIRE_VENV=\${PIP_REQUIRE_VENV} PYENV_VERSION=\${PYENV_VERSION} \"\$@\"" \
                  "echo PIP_REQUIRE_VENV=\${PIP_REQUIRE_VENV} PYENV_VERSION=\${PYENV_VERSION} \"\$@\""

  PIP_REQUIRE_VENV="true" run pyenv-virtualenv venv

  unstub_pyenv
  unstub pyenv-which
  unstub pyenv-exec

  assert_success
  assert_output <<OUT
PIP_REQUIRE_VENV= PYENV_VERSION=3.2.1 pip install virtualenv
PIP_REQUIRE_VENV= PYENV_VERSION=3.2.1 virtualenv ${PYENV_ROOT}/versions/venv
rehashed
OUT
}

@test "install pip without using ensurepip" {
  stub_pyenv "3.3.0"
  stub pyenv-which "virtualenv : false" \
                   "pyvenv : echo '${PYENV_ROOT}/versions/bin/pyvenv'" \
                   "pip : echo no pip; false"
  stub pyenv-exec "echo PYENV_VERSION=\${PYENV_VERSION} \"\$@\"" \
                  "echo PYENV_VERSION=\${PYENV_VERSION} no ensurepip; false" \
                  "echo PYENV_VERSION=\${PYENV_VERSION} no setuptools; false" \
                  "echo PYENV_VERSION=\${PYENV_VERSION} setuptools" \
                  "bin=\"${PYENV_ROOT}/versions/venv/bin\";mkdir -p \"\$bin\";touch \"\$bin/pip\";echo PYENV_VERSION=\${PYENV_VERSION} pip"
  stub curl "echo ez_setup.py" \
            "echo get_pip.py"

  run pyenv-virtualenv venv

  unstub_pyenv
  unstub pyenv-which
  unstub pyenv-exec

  assert_success
  assert_output <<OUT
PYENV_VERSION=3.3.0 pyvenv ${PYENV_ROOT}/versions/venv
PYENV_VERSION=venv no ensurepip
PYENV_VERSION=venv setuptools
PYENV_VERSION=venv pip
rehashed
OUT
  assert [ -e "${PYENV_ROOT}/versions/venv/bin/pip" ]
}
