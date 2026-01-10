variable "cluster_name" {
  description = "A name to provide for the Talos cluster"
  type        = string
}

variable "iso_path" {
  description = "Path to the Talos ISO"
  type        = string
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
