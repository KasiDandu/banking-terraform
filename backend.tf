terraform {
  # Bucket/key/region are supplied at init time via -backend-config
  # (see Makefile), so this repo works across environments without
  # editing committed files.
  backend "s3" {}
}
