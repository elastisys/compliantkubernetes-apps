#!/usr/bin/env bats

# These tests are generated into these files:
# - tests/unit/bin/init/test-kubespray-aws-air-gapped.gen.bats
# - tests/unit/bin/init/test-kubespray-aws-dev.gen.bats
# - tests/unit/bin/init/test-kubespray-aws-prod.gen.bats
# - tests/unit/bin/init/test-kubespray-baremetal-air-gapped.gen.bats
# - tests/unit/bin/init/test-kubespray-baremetal-dev.gen.bats
# - tests/unit/bin/init/test-kubespray-baremetal-prod.gen.bats
# - tests/unit/bin/init/test-kubespray-citycloud-air-gapped.gen.bats
# - tests/unit/bin/init/test-kubespray-citycloud-dev.gen.bats
# - tests/unit/bin/init/test-kubespray-citycloud-prod.gen.bats
# - tests/unit/bin/init/test-kubespray-elastx-air-gapped.gen.bats
# - tests/unit/bin/init/test-kubespray-elastx-dev.gen.bats
# - tests/unit/bin/init/test-kubespray-elastx-prod.gen.bats
# - tests/unit/bin/init/test-kubespray-exoscale-air-gapped.gen.bats
# - tests/unit/bin/init/test-kubespray-exoscale-dev.gen.bats
# - tests/unit/bin/init/test-kubespray-exoscale-prod.gen.bats
# - tests/unit/bin/init/test-kubespray-safespring-air-gapped.gen.bats
# - tests/unit/bin/init/test-kubespray-safespring-dev.gen.bats
# - tests/unit/bin/init/test-kubespray-safespring-prod.gen.bats
# - tests/unit/bin/init/test-kubespray-upcloud-air-gapped.gen.bats
# - tests/unit/bin/init/test-kubespray-upcloud-dev.gen.bats
# - tests/unit/bin/init/test-kubespray-upcloud-prod.gen.bats
# - tests/unit/bin/init/test-capi-aws-air-gapped.gen.bats
# - tests/unit/bin/init/test-capi-aws-dev.gen.bats
# - tests/unit/bin/init/test-capi-aws-prod.gen.bats
# - tests/unit/bin/init/test-capi-baremetal-air-gapped.gen.bats
# - tests/unit/bin/init/test-capi-baremetal-dev.gen.bats
# - tests/unit/bin/init/test-capi-baremetal-prod.gen.bats
# - tests/unit/bin/init/test-capi-citycloud-air-gapped.gen.bats
# - tests/unit/bin/init/test-capi-citycloud-dev.gen.bats
# - tests/unit/bin/init/test-capi-citycloud-prod.gen.bats
# - tests/unit/bin/init/test-capi-elastx-air-gapped.gen.bats
# - tests/unit/bin/init/test-capi-elastx-dev.gen.bats
# - tests/unit/bin/init/test-capi-elastx-prod.gen.bats
# - tests/unit/bin/init/test-capi-exoscale-air-gapped.gen.bats
# - tests/unit/bin/init/test-capi-exoscale-dev.gen.bats
# - tests/unit/bin/init/test-capi-exoscale-prod.gen.bats
# - tests/unit/bin/init/test-capi-safespring-air-gapped.gen.bats
# - tests/unit/bin/init/test-capi-safespring-dev.gen.bats
# - tests/unit/bin/init/test-capi-safespring-prod.gen.bats
# - tests/unit/bin/init/test-capi-upcloud-air-gapped.gen.bats
# - tests/unit/bin/init/test-capi-upcloud-dev.gen.bats
# - tests/unit/bin/init/test-capi-upcloud-prod.gen.bats
