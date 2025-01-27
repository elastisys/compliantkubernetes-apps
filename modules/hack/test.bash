#!/bin/bash

set -euo pipefail
shopt -s inherit_errexit

here="$(dirname "$(readlink -f "$0")")"

command="${1}"
helmfile_environment="${2}"
package_name="${3}"
module_release_name="${4:-"module-${package_name}"}"
old_release_name="${5:-"${module_release_name#"module-"}"}"
template="${6:-""}"

package_path="${here}/../${package_name}"
helmfile_path="${here}/../../helmfile.d"

helm_template() {
  helmfile -f "${helmfile_path}" -e "${helmfile_environment}" template --selector name="module-${module_release_name#"module-"}"${template:+ --args "-s templates/${template}.yaml"}
}

helm_template_main() {
  git worktree add main --quiet
  trap 'git worktree remove main' RETURN ERR

  helmfile -f "./main/helmfile.d" -e "${helmfile_environment}" template --selector name="${old_release_name}"
  : # TODO: helmfile as the last command prevents the trap from firing for some reason
}

render() {
  helm_template |
    crossplane render /dev/stdin "${package_path}/apis/composition.yaml" "${here}/render-resources/functions.yaml" \
      --extra-resources "${here}/render-resources/extra-resources.yaml" \
      --include-context |
    yq4 'select(.kind == "Release" and .metadata.name == "'"${old_release_name}"'")'
}

crossplane_template() {
  render | "${here}/crossplane-helm.bash" template "${old_release_name}" /dev/stdin
}

validate() {
  helm_template | crossplane beta validate "${package_path}/apis" -
}

diff_release() {
  render | "${here}/crossplane-helm.bash" diff "${old_release_name}" /dev/stdin
}

diff_main_template() {
  a=$(helm_template_main)
  b=$(crossplane_template)
  diff --unified --color <(echo "${a}") <(echo "${b}")
}

case "${command}" in
"helm-template") helm_template ;;
"render") render ;;
"crossplane-template") crossplane_template ;;
"validate") validate ;;
"diff-release") diff_release ;;
"diff-main-template") diff_main_template ;;
"dev") validate && diff_main_template ;;
esac
