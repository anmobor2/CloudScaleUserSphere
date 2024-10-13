variable "location" {
  type    = string
  default = "East US"
}

variable "environment" {
  type = string
  default = "dev"
}

variable "docker_image_name" {
  description = "The full name of the Docker image to deploy, including registry and tag"
  type        = string
}

variable "image_name" {
  description = "The name of the Docker image to deploy"
  default     = "flask-app"
}