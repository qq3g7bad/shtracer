# ✅ README.md

For unit testing.

## ⚽ Getting started

1. Open bash.
1. Set the current directory at this repository.
1. Enter the following commands.

```bash
# Ensure you are in the project root directory (you are currently in the "test" directory)
cd ../../
ls # CHANGELOG.md  LICENSE  README.md  docs  sample  scripts  shtracer

# Update submodule

git submodule update --init

# Change mode

chmod +x ./shtracer
chmod +x ./scripts/test/unit_test/*.sh
chmod +x ./scripts/test/integration_test/*.sh

# Start unit tests

./shtracer -t

```

## Test scripts

filename                                      | test target
--------------------------------------------- | ---------------
run_all_tests.sh                              | Test runner - executes all unit and integration tests
unit_test/shtracer_main_unittest.sh           | Main routine (`../../shtracer`)
unit_test/shtracer_func_unittest.sh           | Core functions (`../main/shtracer_func.sh`)
unit_test/shtracer_viewer_unittest.sh         | HTML viewer (`../main/shtracer_viewer.sh`)
unit_test/shtracer_json_unittest.sh           | JSON export (`../main/shtracer_func.sh`)
unit_test/shtracer_version_unittest.sh        | File version information (`../main/shtracer_util.sh`)
unit_test/shtracer_util_unittest.sh           | Utility functions (`../main/shtracer_util.sh`)
integration_test/shtracer_integration_test.sh | End-to-end integration tests
