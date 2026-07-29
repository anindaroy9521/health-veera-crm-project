terraform {

  backend "s3" {

    bucket = "veera-terraform-state"

    key = "healthcare/terraform.tfstate"

    region = "us-east-1"

    encrypt = true

  }

}


###Create the backend bucket once (or manage it separately) before running terraform init with this backend.###