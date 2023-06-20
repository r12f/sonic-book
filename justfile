#!/usr/bin/env just --justfile

COLOR_GREEN := 'Green'
COLOR_BLUE := 'Blue'
COLOR_RED := 'Red'

ROOT_DIR := replace(justfile_directory(), "\\", "/")

set shell := ["pwsh", "-NoLogo", "-Command"]

#
# Build tasks
#
default: serve

init:
    cargo install mdbook
    cargo install mdbook-i18n
    cargo install mdbook-admonish
    cargo install mdbook-pagetoc
    cargo install mdbook-mermaid

build:
    @just _log-head "Building book..."
    mdbook build

serve:
    @just _log-head "Starting mdbook server..."
    mdbook serve

#
# Utility tasks
#
_log-head LOG_LINE:
    @just _log-inner "{{COLOR_GREEN}}" "INFO!" "{{LOG_LINE}}"

_log-info LOG_LINE:
    @just _log-inner "{{COLOR_BLUE}}" "INFO " "{{LOG_LINE}}"

_log-error LOG_LINE:
    @just _log-inner "{{COLOR_RED}}" "ERROR" "{{LOG_LINE}}"

_log-inner COLOR LOG_LEVEL LOG_LINE:
    @if ("{{LOG_LINE}}" -eq "") { echo ""; } else { Write-Host -ForegroundColor "{{COLOR}}" "[$(Get-Date -UFormat '%Y-%m-%d %H:%M:%S')][{{LOG_LEVEL}}] {{LOG_LINE}}"; }