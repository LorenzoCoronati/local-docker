#!/usr/bin/env bash
# File
#
# This file contains restore -command for local-docker script ld.sh.

function ld_command_restore_exec() {
  echo "Deprecated. Use ./ld db-restore to restore using the whole DB container's backup, or './ld db-import [NAME]' to import one database."
 }

#function ld_command_restore_help() {
#}
