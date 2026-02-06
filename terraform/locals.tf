locals {
  tags = {
    source     = "terraform"
    managed    = "as-code"
    repository = var.repository
  }
}