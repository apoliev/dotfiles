#!/bin/bash

dump() {
    echo "$(dconf dump /org/gnome/terminal/legacy/profiles:/:$1/)"
}

load() {
    echo "$(dconf load /org/gnome/terminal/legacy/profiles:/:$1/)"
}

show_help() {
    help_text="Usage: terminal_view [COMMAND] [PROFILE ID]"
    help_text="$help_text\nCommand's list:\n"
    help_text="$help_text\tdump - dump settings\n"
    help_text="$help_text\tload - import settings\n"
    printf "$help_text"
}

case "$1" in
    dump)
        dump $2
        ;;
    load)
        load $2
        ;;
    --help)
        show_help
        ;;
    *)
        echo "Command not found!"
        exit 1
esac
