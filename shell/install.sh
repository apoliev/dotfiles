#!/bin/bash

set -e

DIR="$(dirname "$(readlink -f "$0")")"

source $DIR/prompt_utils.sh

(prompt_txt 'Creating lib directory...'
mkdir -p $HOME/.local/lib &&
show_success "Success\n") || (show_error 'Error' && exit 1)

(prompt_txt 'Install prompt_utils...' &&
cp $DIR/prompt_utils.sh $HOME/.local/lib/ &&
show_success "Success") || (show_error 'Error' && exit 1)
