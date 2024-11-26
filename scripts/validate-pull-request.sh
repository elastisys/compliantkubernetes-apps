#!/usr/bin/env bash

set -euo pipefail
shopt -s extglob

declare -a output

# Raw input stage
declare -a raw
if [[ -f "${1:-}" ]]; then
  readarray -t raw < "${1}"
else
  echo "error: missing or invalid file argument" >&2
  exit 1
fi

# Input stage: remove comments, trailing spaces, and multiple newlines
declare -a input
for line in "${raw[@]}"; do
  # If we're not in a comment
  if [[ -z "${comment:-}" ]]; then
    # If we enter a comment
    if [[ "${line}" =~ (<!--) ]]; then
      # Stage the part of the line before the comment
      stage="${line%%<!--*}"
      line="${line#"${stage}"}"

      comment="true"

    else
      # Stage trimmed line
      stage="${line%%+( )}"

      # Keep if we have staged content
      if [[ -n "${stage}" ]]; then
        input+=("${stage}")
      # Keep if we have input content and last input line had content
      elif [[ -n "${input[*]:-}" ]] && [[ -n "${input[-1]:-}" ]]; then
        input+=("${stage}")
      fi
      # Multiple empty lines will be skipped
    fi
  fi

  # While we're in a comment
  while [[ -n "${comment:-}" ]]; do
    # If we exit a comment
    if [[ "${line}" =~ (-->) ]]; then
      line="${line#*-->}"

      # If we enter a comment
      if [[ "${line}" =~ (<!--) ]]; then
        # Stage the part of the line before the comment
        stage="${stage}${line%%<!--*}"
        line="${line#"${stage}"}"

        comment="true"

      else
        # Stage trimmed line
        stage="${stage}${line}"
        stage="${stage%%+( )}"

        # Keep if we have staged content
        if [[ -n "${stage}" ]]; then
          input+=("${stage}")
        # Keep if we have input content and last input line had content
        elif [[ -n "${input[*]:-}" ]] && [[ -n "${input[-1]:-}" ]]; then
          input+=("${stage}")
        fi
        # Multiple empty lines will be skipped

        comment=""
      fi

    else
      break
    fi
  done
done


# Find kinds
declare -a kinds
for line in "${input[@]}"; do
  # start of line, optional space, dash, variable space, checkbox, variable space, kind, slash
  if [[ "${line}" =~ ^[[:space:]]*-[[:space:]]+\[x\][[:space:]]+kind/ ]]; then
    kinds+=("${line#*([[:space:]])-+([[:space:]])\[x\]+([[:space:]])kind/}")
  fi
done

# Check that it contains required kinds
if ! [[ "${kinds[*]}" =~ (feature|improvement|deprecation|documentation|clean-up|bug|other) ]]; then
  output+=("pull request has no required kind (feature|improvement|deprecation|documentation|clean-up|bug|other)")
fi

for kind in "${kinds[@]}"; do
  if [[ "${kind}" =~ (feature|improvement|deprecation|documentation|clean-up|bug|other) ]]; then
    # Check that it contains only one required kind
    if [[ "${kinds[*]/"${kind}"/}" =~ (feature|improvement|deprecation|documentation|clean-up|bug|other) ]]; then
      output+=("pull request has multiple required kinds (feature|improvement|deprecation|documentation|clean-up|bug|other)")
      break
    fi
  fi
done

# Find admin-change notice
declare -a admin_notice
if [[ "${kinds[*]}" =~ admin-change ]]; then
  for line in "${input[@]}"; do
    if [[ -z "${admin_notice_found:-}" ]]; then
      # Enter section
      if [[ "${line}" =~ ^(### Platform Administrator notice) ]]; then
        admin_notice_found="true"
      fi
    else
      # Exit section
      if [[ "${line}" =~ ^# ]]; then
        break
      # Keep if we have content
      elif [[ -n "${line}" ]]; then
        admin_notice+=("${line}")
      # Keep if we have section content and last section line had content
      elif [[ -n "${admin_notice[*]:-}" ]] && [[ -n "${admin_notice[-1]:-}" ]]; then
        admin_notice+=("${line}")
      fi
      # Multiple empty lines will be skipped
    fi
  done

  if [[ -z "${admin_notice_found:-}" ]]; then
    output+=("pull request has kind/admin-change but no \"Platform Administrator notice\" section")
  elif [[ -z "${admin_notice[*]:-}" ]]; then
    output+=("pull request has kind/admin-change but no \"Platform Administrator notice\" message")
  fi
fi

# Find dev-change notice
declare -a dev_notice
if [[ "${kinds[*]}" =~ dev-change ]]; then
  for line in "${input[@]}"; do
    if [[ -z "${dev_notice_found:-}" ]]; then
      # Enter section
      if [[ "${line}" =~ ^(### Application Developer notice) ]]; then
        dev_notice_found="true"
      fi
    else
      # Exit section
      if [[ "${line}" =~ ^# ]]; then
        break
      # Keep if we have content
      elif [[ -n "${line}" ]]; then
        dev_notice+=("${line}")
      # Keep if we have section content and last section line had content
      elif [[ -n "${dev_notice[*]:-}" ]] && [[ -n "${dev_notice[-1]:-}" ]]; then
        dev_notice+=("${line}")
      fi
      # Multiple empty lines will be skipped
    fi
  done

  if [[ -z "${dev_notice_found:-}" ]]; then
    output+=("pull request has kind/dev-change but no \"Application Developer notice\" section")
  elif [[ -z "${dev_notice[*]:-}" ]]; then
    output+=("pull request has kind/dev-change but no \"Application Developer notice\" message")
  fi
fi

# Find security notice
declare -a security_notice
if [[ "${kinds[*]}" =~ security ]]; then
  for line in "${input[@]}"; do
    if [[ -z "${security_notice_found:-}" ]]; then
      # Enter section
      if [[ "${line}" =~ ^(### Security notice) ]]; then
        security_notice_found="true"
      fi
    else
      # Exit section
      if [[ "${line}" =~ ^# ]]; then
        break
      # Keep if we have content
      elif [[ -n "${line}" ]]; then
        security_notice+=("${line}")
      # Keep if we have section content and last section line had content
      elif [[ -n "${security_notice[*]:-}" ]] && [[ -n "${security_notice[-1]:-}" ]]; then
        security_notice+=("${line}")
      fi
      # Multiple empty lines will be skipped
    fi
  done

  if [[ -z "${security_notice_found:-}" ]]; then
    output+=("pull request has kind/security but no \"Security notice\" section")
  elif [[ -z "${security_notice[*]:-}" ]]; then
    output+=("pull request has kind/security but no \"Security notice\" message")
  fi
fi

# Find kind/adr
for line in "${input[@]}"; do
  if [[ "${line}" =~ ^[[:space:]]*-[[:space:]]+\[x\][[:space:]]*+\[kind/adr\]\(\) ]]; then
    output+=("pull request has kind/adr but no link")
  elif [[ "${line}" =~ ^[[:space:]]*-[[:space:]]+\[x\][[:space:]]*+\[kind/adr\] ]] && ! [[ "${line}" =~ ^[[:space:]]*-[[:space:]]+\[x\][[:space:]]*+\[kind/adr\]\(https://elastisys.io/welkin/adr/ ]]; then
    output+=("pull request has kind/adr with invalid link")
  fi
done

# Output stage: Custom annotations for GitHub Actions and regular error output otherwise
if [[ -n "${output[*]:-}" ]]; then
  if [[ -n "${GITHUB_ACTIONS:-}" ]]; then
    echo "pull request failed validation:" >> "${GITHUB_STEP_SUMMARY:-}"
    for line in "${output[@]}"; do
      echo "- ${line}" >> "${GITHUB_STEP_SUMMARY:-}"
      echo "::error ::${line}"
    done
  else
    echo "pull request failed validation:" >&2
    for line in "${output[@]}"; do
      echo "- ${line}" >&2
    done
  fi
  exit 1
fi
