#!/bin/bash
# This would be site defined
exec erb -r pathname user_name="$USER" home="$HOME" "$@"