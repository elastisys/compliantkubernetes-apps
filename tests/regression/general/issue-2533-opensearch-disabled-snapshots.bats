#!/usr/bin/env bats

setup() {
  load "../../bats.lib.bash"
  load_common "env.bash"
  load_common "gpg.bash"
  load_common "yq.bash"
  load_assert

  env.setup
  gpg.setup

  env.init baremetal kubespray prod
}

teardown() {
  env.teardown
  gpg.teardown
}

@test "issue 2533 - disabled opensearch snapshots should not break templating" {
  yq.set sc '.opensearch.snapshot.enabled' 'false'
  ck8s init sc
  run ck8s ops helmfile sc template -l app=opensearch
  refute_output --regexp '<\.Values\.config\.snapshots\.[^>]+>:\s+nil\s+pointer\s+evaluating\s+interface\s+\{\}\.\S+'
}
