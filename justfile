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
    @just _log-head "Building book ..."
    mdbook build
    just po-build en

serve:
    @just _log-head "Starting mdbook server ..."
    mdbook serve -n 0.0.0.0

po-extract:
    @just _log-head "Extracting messages.pot file from source  ..."
    $env:MDBOOK_OUTPUT='{"xgettext": {"pot-file": "messages.pot"}}'; mdbook build -d po; $env:MDBOOK_OUTPUT=$null

po-update PO='en':
    @just _log-head "Updating po files for language {{PO}} ..."
    msgmerge --update po/{{PO}}.po po/messages.pot

po-build PO='en':
    @just _log-head "Building book for language {{PO}} ..."
    $env:MDBOOK_BOOK__LANGUAGE="{{PO}}"; mdbook build -d book/{{PO}}; $env:MDBOOK_BOOK__LANGUAGE=$null

po-serve PO='en':
    @just _log-head "Starting mdbook server with translated {{PO}} book ..."
    $env:MDBOOK_BOOK__LANGUAGE="{{PO}}"; mdbook serve -d book/{{PO}} -n 0.0.0.0; $env:MDBOOK_BOOK__LANGUAGE=$null

po-tr PO='en':
    @just _log-head "Starting translating {{PO}} book ..."
    potr -p ./po/{{PO}}.po -e deepl -t {{PO}}

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