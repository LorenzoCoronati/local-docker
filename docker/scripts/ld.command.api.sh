#!/usr/bin/env bash
# File
#
# This file contains COMMAND -command for local-docker script ld.sh.
# The file name must follow pattern "ld.command.COMMAND.sh" and it must be
# locate in docker/scripts/ -folder.

function ld_command_COMMAND_exec() {
    # DOES STUFF
    # Commands are executed in PROJECT_ROOT folder.
    # Several environmental variables are available, see files ld.sh. env.example.
    which docker-compose
}

function ld_command_COMMAND_help() {
    # PRINTS HELP INFO
    #
    # Info will be printed with help -command after the command name.
    # In case you intend to add more than one line, please indent the
    # second line etc. with 4 spaces.
    #
    # NOTE: For internal commands comment out this function. This way the command
    # NOTE: is not printed in the commands list.
    # This would print in UI (after general info).
    # - COMMAND - Command is super handy thing to use.
    echo "Command is super handy thing to use."
}
