git_sc <- system2("git", c("rev-parse","--is-inside-work-tree"), stdout = F, stderr = F)
if (git_sc != 0) {
  cat("  Not in a git repository, skipping bootstrap.R\n")
  return()
}

cat("  Installing dependencies\n")
devtools::install_dev_deps('.', upgrade = "never")

pkg_version <- package_version(desc::desc_get("Version"))
is_dev <- pkg_version[1, 4] == "9000"

if (!is_dev) {
  cat("  Removing badges from Readme.md\n")
  system2("sed", c("-i", "/^<!-- badges: start -->$/,/^<!-- badges: end -->$/d", "Readme.md"))
}
print('running bootstrap.R')
