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
    cargo install mdbook-open-on-gh

init-builder:
    @just install-gh-bin https://github.com/rust-lang/mdBook/releases/download/v0.4.32/mdbook-v0.4.32-x86_64-unknown-linux-gnu.tar.gz mdbook
    cargo install mdbook-i18n-helpers
    @just install-gh-bin https://github.com/tommilligan/mdbook-admonish/releases/download/v1.10.1/mdbook-admonish-v1.10.1-x86_64-unknown-linux-gnu.tar.gz mdbook-admonish
    @just install-gh-bin https://github.com/slowsage/mdbook-pagetoc/releases/download/v0.1.7/mdbook-pagetoc-v0.1.7-x86_64-unknown-linux-gnu.tar.gz mdbook-pagetoc
    @just install-gh-bin https://github.com/badboy/mdbook-mermaid/releases/download/v0.12.6/mdbook-mermaid-v0.12.6-x86_64-unknown-linux-gnu.tar.gz mdbook-mermaid
    @just install-gh-bin https://github.com/badboy/mdbook-open-on-gh/releases/download/2.3.3/mdbook-open-on-gh-2.3.3-x86_64-unknown-linux-gnu.tar.gz mdbook-open-on-gh

install-gh-bin GITHUB_PATH BIN_NAME:
    @just _log-head "Installing {{BIN_NAME}} from {{GITHUB_PATH}} ..."
    rm -f bin.tar.gz
    wget {{GITHUB_PATH}} -O bin.tar.gz
    tar zxvf ./bin.tar.gz
    chmod +x ./{{BIN_NAME}}
    mv ./{{BIN_NAME}} ~/.cargo/bin
    @just _log-info "Installing {{BIN_NAME}} completed!"

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