variable "address_space" {
  type = string
  default = "10.0.0.0/16"
}

variable "address_prefixes" {
  type = string
  default = "10.0.2.0/24"
}





variable "env" {
  type = string
  default = "kfg"
}

variable "reg" {
  type = string
  default = "ue"
}

variable "dom" {
  type = string
  default = "dv"
}

variable "rstype" {
  type = string
  default = "rg"
}

variable "index" {
  type = string
  default = "01"
}

variable "index1" {
  type = string
  default = "02"
}


variable "vnet" {
  type = string
  default = "vtn-network"
}

variable "snet" {
  type = string
  default = "st-internal"
}

variable "vnet1" {
  type = string
  default = "vtn1-network"
}

variable "snet1" {
  type = string
  default = "st1-internal"
}

variable "vnet2" {
  type = string
  default = "vtn2-network"
}

variable "snet2" {
  type = string
  default = "st2-internal"
}

variable "nic" {
  type = string
  default = "example-nic"
}

variable "vmname" {
  type = string
  default = "example-machine"
}

variable "location" {
  type = string
  default = "eastus"
}

variable "adminlogin" {
  type = string
  default = "pinku"
}

variable "loginpassword" {
  type = string
  default = "Urg3u_*jblSF+^q-"
}
