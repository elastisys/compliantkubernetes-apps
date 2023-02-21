#!/usr/bin/env bash

HERE="$(dirname "$(readlink -f "${0}")")"
ROOT="$(readlink -f "${HERE}/../../../")"

# shellcheck source=scripts/migration/lib.sh
source "${ROOT}/scripts/migration/lib.sh"

# functions currently available in the library:
#   - logging:
#     - log_info(_no_newline) <message>
#     - log_warn(_no_newline) <message>
#     - log_error(_no_newline) <message>
#     - log_fatal <message> # this will call "exit 1"
#
#  - yq:
#     - yq_null <common|sc|wc> <target>
#     - yq_copy <common|sc|wc> <source> <destination>
#     - yq_move <common|sc|wc> <source> <destination>
#     - yq_remove <common|sc|wc> <target>
#     - yq_add <common|sc|wc> <target> <destination> <value>

# Note: 00-template.sh will be skipped by the upgrade command
log_info "no operation: this is a template"
