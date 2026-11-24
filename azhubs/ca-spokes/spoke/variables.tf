variable "hub" {
  type = object({
    name   = any
    config = any
  })
}
variable "spoke" {
  type = object({
    name                  = string
    project               = any
    owner_group_object_id = string
  })
}
variable "project" {
  type = any
}
variable "org" {
  type = any
}
