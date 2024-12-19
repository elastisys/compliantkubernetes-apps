#!/usr/bin/env bash

# Common bash functions

declare CK8S_EXECUTOR
CK8S_EXECUTOR="ck8s/$(basename "${0}")"

# Colour escape functions

# Conditionally colour when stderr is connected to a terminal.
if [[ -t 2 ]]; then
  esc.red() {
    printf "\e[31m%s\e[0m" "${*}"
  }
  esc.grn() {
    printf "\e[32m%s\e[0m" "${*}"
  }
  esc.ylw() {
    printf "\e[33m%s\e[0m" "${*}"
  }
  esc.blu() {
    printf "\e[34m%s\e[0m" "${*}"
  }
  esc.prp() {
    printf "\e[35m%s\e[0m" "${*}"
  }
  esc.cyn() {
    printf "\e[36m%s\e[0m" "${*}"
  }
  esc.gry() {
    printf "\e[37m%s\e[0m" "${*}"
  }
else
  esc.red() {
    printf "%s" "${*}"
  }
  esc.grn() {
    printf "%s" "${*}"
  }
  esc.ylw() {
    printf "%s" "${*}"
  }
  esc.blu() {
    printf "%s" "${*}"
  }
  esc.prp() {
    printf "%s" "${*}"
  }
  esc.cyn() {
    printf "%s" "${*}"
  }
  esc.gry() {
    printf "%s" "${*}"
  }
fi

# Logging functions

log.good.no_newline() {
  echo -en "[$(esc.grn "${CK8S_EXECUTOR}")] ${*}" 1>&2
}
log.good() {
  log.good.no_newline "${*}\n"
}
log.info.no_newline() {
  echo -en "[$(esc.blu "${CK8S_EXECUTOR}")] ${*}" 1>&2
}
log.info() {
  log.info.no_newline "${*}\n"
}
log.warn.no_newline() {
  echo -en "[$(esc.ylw "${CK8S_EXECUTOR}")] ${*}" 1>&2
}
log.warn() {
  log.warn.no_newline "${*}\n"
}
log.error.no_newline() {
  echo -en "[$(esc.red "${CK8S_EXECUTOR}")] ${*}" 1>&2
}
log.error() {
  log.error.no_newline "${*}\n"
}
log.fatal() {
  log.error "${*}"
  exit 1
}
log.fatal.nested() {
  shopt -s extdebug
  local -a function
  readarray -t function <<< "$(declare -F "${FUNCNAME[1]}" | tr ' ' '\n')"

  log.error "in $(esc.red "${function[0]} at ${function[2]}:${function[1]}"): ${*}\n--- This is invalid use of a helper functions and must be fixed ---"
  exit 1
}
log.continue() {
  if [[ "${CK8S_AUTO_APPROVE:-false}" != "true" ]]; then
    if [[ -t 0 ]]; then
      log.warn.no_newline "${*} - [y/N]: "

      local reply
      read -r reply
      if ! [[ "${reply}" =~ ^(y|Y|yes|Yes|YES)$ ]]; then
        return 1
      fi
    else
      log.fatal "not connected to a terminal, unable to prompt user"
    fi
  fi
}

# Version functions

declare -A ver

# Parse and populate the ver associative array with <name>-major, <name>-minor, <name>-patch, <name>-tag.
# TODO: Validation...
ver.parse() { # <name> <version>
  local name="${1:-}" version="${2:-}"

  [[ -n "${name}" ]] || log.fatal.nested "missing required argument $(esc.ylw "<name>")"
  [[ -n "${version}" ]] || log.fatal.nested "missing required argument $(esc.ylw "<version>")"

  version="${version#v}"

  if [[ "${version}" =~ - ]]; then
    ver["${name}-suffix"]="${version##*-}"
    version="${version%%-*}"
  else
    ver["${name}-suffix"]=""
  fi

  ver["${name}-major"]="${version%%.*}"
  version="${version#*.}"
  ver["${name}-minor"]="${version%%.*}"
  version="${version#*.}"
  ver["${name}-patch"]="${version}"
}

# Compares if a version is greater than another
ver.gt() { # <name-greater> <name-lesser>
  local greater="${1:-}" lesser="${2:-}"

  [[ -n "${greater}" ]] || log.fatal.nested "missing required argument $(esc.ylw "<greater>")"
  [[ -n "${lesser}" ]] || log.fatal.nested "missing required argument $(esc.ylw "<lesser>")"

  for section in "major" "minor" "patch" "tag"; do
    if [[ "${ver["${greater}-${section}"]}" -gt "${ver["${lesser}-${section}"]}" ]]; then
      return 0
    elif [[ "${ver["${greater}-${section}"]}" -lt "${ver["${lesser}-${section}"]}" ]]; then
      return 1
    fi
  done

  # Equal
  return 1
}

# Resolve yq

yq() {
  if command -v yq4 >/dev/null; then
    command yq4 "${@}"
  else
    command yq "${@}"
  fi
}
