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

git_sc <- system2("git", c("rev-parse", "--is-inside-work-tree"), stdout = FALSE, stderr = FALSE)
if (git_sc != 0) {
  cli::cli_alert_warning("Not in a git repository, skipping bootstrap.R")
  q(save = "no")
}

pkg_version <- package_version(desc::desc_get("Version"))
is_release <- is.na(pkg_version[1, 4]) || pkg_version[1, 4] < "100"
# for testing and CI
force_bootstrap <- identical(tolower(Sys.getenv("ARROW_FORCE_BOOTSTRAP", unset = "false")), "true")

get_checksum_version <- function() {
  url_exists <- function(url) {
    headers <- curlGetHeaders(url)
    attr(headers, "status") == 200
  }
  # Run update-checksums.R manually if the checksums already exists
  # but have an unexpected version.
  if (dir.exists("tools/checksums") || force_bootstrap) {
    cli::cli_alert_success("Found existing checksums, skipping download.")
    return(NA)
  }

  # We currently don't support prebuild binaries with a differing version.
  jfrog_url <- "https://apache.jfrog.io/artifactory/arrow/r/%s/libarrow"
  matching_url <- url_exists(sprintf(jfrog_url, pkg_version[1, 1:3]))
  if (matching_url) {
    version <- pkg_version[1, 1:3]
  } else {
    cli::cli_abort("No matching checksums found, can't proceed.")
  }
  version
}

if (!is_release) {
  cli::cli_alert_warning("Skipping releases preparations for dev version.")
  q(save = "no")
}

cli::cli_alert_info("Installing dependencies")
devtools::install_dev_deps(".", upgrade = "never")
devtools::install_cran("styler")

cli::cli_alert_info("Removing badges from Readme.md")
system2("sed", c("-i", "'/^<!--- badges: start -->$/,/^<!--- badges: stop -->$/d'", "README.md"))

cli::cli_alert_info("Running urlchecker")
url_res <- urlchecker::url_check()
print(url_res)

if (nrow(url_res) > 0 && !force_bootstrap) {
  cli::cli_abort("Broken URLs found, can't proceed.")
}

VERSION <- get_checksum_version()
if (!is.na(VERSION)) {
  cli::cli_alert_info("Updating checksums for libarrow version: {VERSION}")
  source("tools/update-checksums.R", local = TRUE)
}

cli::cli_alert_info("Vendoring C++ sources")
system2("make", c("sync-cpp"))

cli::cli_alert_info("Building documentation")
system2("make", c("doc"))

cli::cli_alert_success("Done!")
