#!/usr/bin/env bash
# Licensed to the Apache Software Foundation (ASF) under one
# or more contributor license agreements.  See the NOTICE file
# distributed with this work for additional information
# regarding copyright ownership.  The ASF licenses this file
# to you under the Apache License, Version 2.0 (the
# "License"); you may not use this file except in compliance
# with the License.  You may obtain a copy of the License at
#
#   http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing,
# software distributed under the License is distributed on an
# "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
# KIND, either express or implied.  See the License for the
# specific language governing permissions and limitations
# under the License.

set -ex

: ${R_BIN:=R}

source_dir=${1}/r

# cpp building dependencies
apt update -y -q && \
apt install -y \
  cmake \
  libbrotli-dev \
  libbz2-dev \
  libc-ares-dev \
  libcurl4-openssl-dev \
  libgflags-dev \
  libgoogle-glog-dev \
  liblz4-dev \
  libprotobuf-dev \
  libprotoc-dev \
  libradospp-dev \
  libre2-dev \
  libsnappy-dev \
  libssl-dev \
  libthrift-dev \
  libutf8proc-dev \
  libzstd-dev \
  nlohmann-json3-dev \
  pkg-config \
  protobuf-compiler \
  python3-dev \
  python3-pip \
  python3-rados \
  rados-objclass-dev \
  rapidjson-dev \
  tzdata \
  wget

# system dependencies needed for arrow's reverse dependencies
apt install -y libxml2-dev \
  libfontconfig1-dev \
  libcairo2-dev \
  libglpk-dev \
  libmysqlclient-dev \
  unixodbc-dev \
  libpq-dev \
  coinor-libsymphony-dev \
  coinor-libcgl-dev \
  coinor-symphony \
  libzmq3-dev \
  libudunits2-dev \
  libgdal-dev \
  libgeos-dev \
  libproj-dev



pushd ${source_dir}

printenv

# By default, aws-sdk tries to contact a non-existing local ip host
# to retrieve metadata. Disable this so that S3FileSystem tests run faster.
export AWS_EC2_METADATA_DISABLED=TRUE

# Set crancache dir so we can cache it
export CRANCACHE_DIR="/arrow/.crancache"

# Don't use system boost to prevent issues with missing components 
export EXTRA_CMAKE_FLAGS='-DBoost_SOURCE=BUNDLED'

SCRIPT="
    # We can't use RSPM binaries because we need source packages
    options('repos' = c(CRAN = 'https://packagemanager.rstudio.com/all/latest'))
    remotes::install_github('r-lib/revdepcheck')

    # zoo is needed by RcisTarget tests, though only listed in enhances so not installed by revdepcheck
    install.packages('zoo')

    # actually run revdepcheck
    revdepcheck::revdep_check(
    quiet = FALSE,
    timeout = as.difftime(120, units = 'mins'),
    num_workers = 2,
    env = c(
        ARROW_R_DEV = '$ARROW_R_DEV',
        LIBARROW_DOWNLOAD = TRUE,
        LIBARROW_MINIMAL = FALSE,
        revdepcheck::revdep_env_vars()
    ))

    revdepcheck::revdep_report(all = TRUE)

    # Go through the summary and fail if any of the statuses include -
    summary <- revdepcheck::revdep_summary()
    failed <- lapply(summary, function(check) grepl('-', check[['status']]))

    if (any(unlist(failed))) {
      quit(status = 1)
    }
    "

echo "$SCRIPT" | ${R_BIN} --no-save

popd
