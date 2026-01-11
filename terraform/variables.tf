variable "cluster_name" {
  description = "A name to provide for the Talos cluster"
  type        = string
  default     = "k8s"
}

variable "iso_path" {
  description = "Path to the Talos ISO"
  type        = string
  default     = "/metal-amd64.iso"
}

variable "cluster_size" {
  description = "The cluster size"
  type = object({
    controlplanes = number
    workers       = number
  })
  default = {
    controlplanes = 1
    workers = 1
  }
}
