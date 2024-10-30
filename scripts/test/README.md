# ✅ README.md

For unit testing.

## ⚽ Getting started

1. Open bash.
1. Set the current directory at this repository.
1. Enter the following commands.

```bash
# Update submodule
git submodule update --init

# Change mode
chmod +x ./shtracer
chmod +x ./scripts/test/shtracer*_test.sh

# Start unit tests
./shtracer -t
```

## Test scripts

filename                | test target
----------------------- | ---------------
shtracer_util_test.sh   | `../main/shtracer_util.sh`
shtracer_uml_test.sh    | `../main/shtracer_uml.sh`
shtracer_func_test.sh   | `../main/shtracer_func.sh`
shtracer_test.sh        | `../../shtracer`

