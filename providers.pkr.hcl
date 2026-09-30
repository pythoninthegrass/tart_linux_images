packer {
  required_plugins {
    tart = {
      source  = "github.com/cirruslabs/tart"
      version = "~> 1.7.0"
    }
    ansible = {
      version = "~> 1.1.3"
      source = "github.com/hashicorp/ansible"
    }
  }
}
