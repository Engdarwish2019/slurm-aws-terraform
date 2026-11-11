provider "aws" {
  region = var.region

  default_tags {
    tags = {
      Project     = var.cluster_name
      Environment = var.environment
      ManagedBy   = "terraform"
    }
  }
}
