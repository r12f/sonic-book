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
    cargo install mdbook-i18n-helpers
    cargo install mdbook-admonish
    cargo install mdbook-pagetoc
    cargo install mdbook-mermaid

build:
    @just _log-head "Building book..."
    mdbook build
    $env:MDBOOK_BOOK__LANGUAGE="en"; mdbook build -d book/en; $env:MDBOOK_BOOK__LANGUAGE=$null

serve:
    @just _log-head "Starting mdbook server..."
    mdbook serve -n 0.0.0.0

init-po:
    $env:MDBOOK_OUTPUT='{"xgettext": {"pot-file": "messages.pot"}}'; mdbook build -d po; $env:MDBOOK_OUTPUT=$null

update-po PO='en':
    @just _log-head "Updating po files for language {{PO}} ..."
    msgmerge --update po/{{PO}}.po po/messages.pot

serve-po PO='en':
    @just _log-head "Starting mdbook server with translated {{PO}} book ..."
    $env:MDBOOK_BOOK__LANGUAGE="{{PO}}"; mdbook serve -d book/{{PO}} -n 0.0.0.0; $env:MDBOOK_BOOK__LANGUAGE=$null

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