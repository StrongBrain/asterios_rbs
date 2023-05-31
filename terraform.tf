terraform {
  cloud {
    organization = "asterios-stream-rbs"

    workspaces {
      name = "asterios_rbs_workspace"
    }
  }
}

provider "aws" {
  region = "eu-central-1"
}
