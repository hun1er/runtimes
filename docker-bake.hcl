# Container registry prefix
variable "REGISTRY" {
  default = ""
}

# Base image name
variable "IMAGE_NAME" {
  default = "runtime"
  validation {
    condition     = IMAGE_NAME != ""
    error_message = "The variable 'IMAGE_NAME' must not be empty."
  }
}

# Release tag
variable "TAG" {
  default = "latest"
  validation {
    condition     = TAG != ""
    error_message = "The variable 'TAG' must not be empty."
  }
}

# Target build architectures
variable "PLATFORMS" {
  default = ["linux/amd64"]
}

# Git commit SHA
variable "REVISION" {
  default = ""
}

# Build timestamp in RFC 3339 format
variable "CREATED" {
  default = ""
}

# BuildKit cache import source
variable "CACHE_FROM" {
  default = ""
}

# BuildKit cache export destination
variable "CACHE_TO" {
  default = ""
}

# Build timezone
variable "TZ" {
  default = "UTC"
  validation {
    condition     = TZ != ""
    error_message = "The variable 'TZ' must not be empty."
  }
}

# Prepend registry prefix to image name
function "prefix" {
  params = [name]
  result = notequal(REGISTRY, "") ? "${REGISTRY}/${name}" : name
}

# Generate image tags based on variant, flavor, and TAG
function "make_tags" {
  params = [variant, flavor]
  result = equal(TAG, "latest") ? [
    "${prefix(IMAGE_NAME)}:${variant}",
    "${prefix(IMAGE_NAME)}:${variant}-${flavor}"
  ] : [
    "${prefix(IMAGE_NAME)}:${variant}",
    "${prefix(IMAGE_NAME)}:${variant}-${flavor}",
    "${prefix(IMAGE_NAME)}:${variant}-${TAG}",
    "${prefix(IMAGE_NAME)}:${variant}-${flavor}-${TAG}"
  ]
}

# Base images
group "base" {
  targets = ["base-debian"]
}

# GoldSrc runtime images
group "goldsrc" {
  targets = ["goldsrc-debian"]
}

# Default build targets
group "default" {
  targets = ["base-debian", "goldsrc-debian"]
}

# All build targets
group "all" {
  targets = ["base-debian", "goldsrc-debian"]
}

# Repository source URL
variable "SOURCE_URL" {
  default = "https://github.com/hun1er/runtimes"
}

# Common settings
target "_common" {
  platforms  = PLATFORMS
  cache-from = notequal(CACHE_FROM, "") ? [CACHE_FROM] : []
  cache-to   = notequal(CACHE_TO, "") ? [CACHE_TO] : []
  attest = [
    "type=provenance,mode=max",
    "type=sbom"
  ]
  args = {
    TZ = "${TZ}"
  }
  labels = {
    "org.opencontainers.image.vendor"        = "the_hunter"
    "org.opencontainers.image.authors"       = "the_hunter"
    "org.opencontainers.image.licenses"      = "MIT"
    "org.opencontainers.image.url"           = "${SOURCE_URL}"
    "org.opencontainers.image.source"        = "${SOURCE_URL}"
    "org.opencontainers.image.documentation" = "${SOURCE_URL}#readme"
    "org.opencontainers.image.revision"      = "${REVISION}"
    "org.opencontainers.image.created"       = "${CREATED}"
  }
}

# Common Debian settings
target "_common-debian" {
  inherits = ["_common"]
  contexts = {
    "scripts" = "./scripts/debian"
  }
}

# Base Debian image
target "base-debian" {
  inherits   = ["_common-debian"]
  context    = "./runtimes/base/debian"
  dockerfile = "Dockerfile"
  tags       = make_tags("base", "debian")
  labels = {
    "org.opencontainers.image.title"       = "Base Runtime"
    "org.opencontainers.image.description" = "Foundational Debian base image with multi-architecture support"
  }
}

# GoldSrc Debian image
target "goldsrc-debian" {
  inherits = ["_common-debian"]
  contexts = {
    "runtime:base-debian" = "target:base-debian"
    "scripts"             = "./scripts/debian"
  }
  context    = "./runtimes/goldsrc/debian"
  dockerfile = "Dockerfile"
  tags       = make_tags("goldsrc", "debian")
  labels = {
    "org.opencontainers.image.title"       = "GoldSrc Runtime"
    "org.opencontainers.image.description" = "Runtime environment for GoldSrc dedicated game servers"
  }
}
