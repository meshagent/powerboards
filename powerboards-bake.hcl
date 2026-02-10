
variable "PLATFORM" {
  default = "linux/amd64"
}
variable "PLATFORMS" {                # single-arch for Minikube
  type = list(string)
  default = [PLATFORM]
}

variable "IMAGE_TAG_PREFIX" {
  type    = string
  default = ""
}

variable "AASA_FILE" {
  type    = string
  default = "apple-app-site-association"
}

variable "POWERBOARDS_UI_TAG" {
  type    = string
  default = "latest"
}

variable "DART_DEFINE_CONFIG" {
  default = "config-local.json"
}

variable "OUTPUT_FLAGS" {
  default = "type=docker"
}

# Anything that inherits _defaults is automatically loaded to the daemon
target "_defaults" {
  context    = "."
  platforms  = PLATFORMS
  output  = [ OUTPUT_FLAGS ]  
}

# ────────────────────────────────────────────────────────────────

target "powerboards-ui" {
  inherits = ["_defaults"]
  dockerfile = "powerboards/powerboards.dockerfile"
  tags     = [ "${IMAGE_TAG_PREFIX}powerboards-ui:${POWERBOARDS_UI_TAG}", "${IMAGE_TAG_PREFIX}powerboards-ui:latest" ]
  args     = {
     "DART_DEFINE_CONFIG" = "${DART_DEFINE_CONFIG}"
     "AASA_FILE" = "${AASA_FILE}"
  }
}

group "default" {
  targets = [
    "powerboards-ui",
  ]
}
