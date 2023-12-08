git_sc <- system2("git", c("rev-parse", "--is-inside-work-tree"), stdout = FALSE, stderr = FALSE)
if (git_sc != 0) {
  cat("Not in a git repository, skipping bootstrap.R\n")
  return()
}

cat("Installing dependencies\n")
devtools::install_dev_deps(".", upgrade = "never")
devtools::install_cran("styler")

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
    cat("Found existing checksums, skipping download.\n")
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
  cat("Removing badges from Readme.md\n")
  system2("sed", c("-i", "'/^<!--- badges: start -->$/,/^<!--- badges: stop -->$/d'", "README.md"))

  VERSION <- get_checksum_version()
  if (!is.na(VERSION)) {
    cat(sprintf("Updating checksums for libarrow version: %s\n", VERSION))
    source("tools/update-checksums.R", local = TRUE)
  }
} else {
  cat("Skipping releases preparations for dev version.\n")
}

cat("Vendoring C++ sources\n")
system2("make", c("sync-cpp"))

cat("Building documentation\n")
system2("make", c("doc"))

cat("Running styler\n")
styler::style_file(setdiff(dir(pattern = "R$", recursive = TRUE), source(".styler_excludes.R")$value))
cat("Done!\n")
