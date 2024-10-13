#!/bin/sh

. ./shtracer

test_global_constant() {
  assertEquals 0 "${TAG_CHANGE_MODE}"
}

. ./scripts/test/shunit2/shunit2
