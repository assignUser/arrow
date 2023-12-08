git_sc <- system2("git", c("rev-parse", "--is-inside-work-tree"), stdout = FALSE, stderr = FALSE)
if (git_sc != 0) {
  cli::cli_alert_warning("Not in a git repository, skipping bootstrap.R")
  return()
}

pkg_version <- package_version(desc::desc_get("Version"))
is_dev <- !is.na(pkg_version[1, 4]) && pkg_version[1, 4] == "9000"

get_checksum_version <- function() {
  url_exists <- function(url) {
    headers <- curlGetHeaders(url)
    attr(headers, "status") == 200
  }
  # Run update-checksums.R manually if the checksums already exists
  # but have an unexpected version.
  if (dir.exists("tools/checksums")) {
    cli::cli_alert_success("Found existing checksums, skipping download.")
    return(NA)
  }

  # We currently don't support prebuild binaries with a differing version.
  jfrog_url <- "https://apache.jfrog.io/artifactory/arrow/r/%s/libarrow"
  matching_url <- url_exists(sprintf(jfrog_url, pkg_version[1, 1:3]))
  if (matching_url) {
    version <- pkg_version[1, 1:3]
  } else {
    stop("No matching checksums found, can't proceed.")
  }
  version
}

if (!is_dev) {
  cli::cli_alert_info("Installing dependencies")
  devtools::install_dev_deps(".", upgrade = "never")
  devtools::install_cran("styler")

  cli::cli_alert_info("Removing badges from Readme.md")
  system2("sed", c("-i", "'/^<!--- badges: start -->$/,/^<!--- badges: stop -->$/d'", "README.md"))

  cli::cli_alert_info("Running urlchecker")
  url_res <- urlchecker::url_check()
  if (nrow(url_res) > 0) {
    print(url_res)
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
} else {
  cli::cli_alert_warning("Skipping releases preparations for dev version.\n")
}



cli::cli_alert_success("Done!")
