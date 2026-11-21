variable "hub" {
  type = object({
    name   = any
    config = any
  })
}
variable "spoke" {
  type = object({
    name    = string
    project = any
  })
}
variable "project" {
  type = any
}
