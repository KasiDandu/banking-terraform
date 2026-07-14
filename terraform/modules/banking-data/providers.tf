provider "aws" {
  region = var.aws_region

  # Set for cross-account promotion (e.g. a prod account reached from a
  # shared CI/deploy identity). Left null, this is a no-op and behaves
  # exactly as before -- credentials come from the ambient environment.
  dynamic "assume_role" {
    for_each = var.assume_role_arn != null ? [var.assume_role_arn] : []
    content {
      role_arn = assume_role.value
    }
  }
}
