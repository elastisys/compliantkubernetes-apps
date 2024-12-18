#!/usr/bin/env bash

CHART="$(dirname "$(dirname "$(readlink -f "${0}")")")"

REPOSITORY="open-policy-agent/gatekeeper-library"
VERSION="master"

declare -A TEMPLATES

# <destination path> <source path>
TEMPLATES["podsecuritypolicies/allow-privilege-escalation"]="library/pod-security-policy/allow-privilege-escalation/template.yaml"
TEMPLATES["podsecuritypolicies/apparmor"]="library/pod-security-policy/apparmor/template.yaml"
TEMPLATES["podsecuritypolicies/capabilities"]="library/pod-security-policy/capabilities/template.yaml"
TEMPLATES["podsecuritypolicies/flexvolume-drivers"]="library/pod-security-policy/flexvolume-drivers/template.yaml"
TEMPLATES["podsecuritypolicies/forbidden-sysctls"]="library/pod-security-policy/forbidden-sysctls/template.yaml"
TEMPLATES["podsecuritypolicies/fsgroup"]="library/pod-security-policy/fsgroup/template.yaml"
TEMPLATES["podsecuritypolicies/host-filesystem"]="library/pod-security-policy/host-filesystem/template.yaml"
TEMPLATES["podsecuritypolicies/host-namespaces"]="library/pod-security-policy/host-namespaces/template.yaml"
TEMPLATES["podsecuritypolicies/host-network-ports"]="library/pod-security-policy/host-network-ports/template.yaml"
TEMPLATES["podsecuritypolicies/privileged-containers"]="library/pod-security-policy/privileged-containers/template.yaml"
TEMPLATES["podsecuritypolicies/proc-mount"]="library/pod-security-policy/proc-mount/template.yaml"
TEMPLATES["podsecuritypolicies/read-only-root-filesystem"]="library/pod-security-policy/read-only-root-filesystem/template.yaml"
TEMPLATES["podsecuritypolicies/seccomp"]="library/pod-security-policy/seccomp/template.yaml"
TEMPLATES["podsecuritypolicies/selinux"]="library/pod-security-policy/selinux/template.yaml"
TEMPLATES["podsecuritypolicies/users"]="library/pod-security-policy/users/template.yaml"
TEMPLATES["podsecuritypolicies/volumes"]="library/pod-security-policy/volumes/template.yaml"

for key in "${!TEMPLATES[@]}"; do
  echo "updating $key"
  template="${CHART}/templates/${key}.yaml"
  mkdir -p "$(dirname "${template}")"
  curl --progress-bar "https://raw.githubusercontent.com/${REPOSITORY}/${VERSION}/${TEMPLATES["${key}"]}" -o "${template}"
done

echo "updating waitFor in values.yaml"

readarray -t templates <<<"$(find "${CHART}/templates/" -type f -name "*.yaml" -not -path "*/wait/*" -not -name "config.yaml")"

list="$(for template in "${templates[@]}"; do grep "name:" "${template}"; done | sed "s/name: /- /" | sort | yq4 -oj)"

yq4 -i ".waitFor = ${list}" "${CHART}/values.yaml"

echo "please restore whitespace changes in values.yaml"
