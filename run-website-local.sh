#!/bin/bash

CONFIG_FILE=config-life.json

while [[ $# -gt 0 ]]
do
key="$1"
case $key in
    --life)
        CONFIG_FILE=config-life.json
        ;;
    --local)
        CONFIG_FILE=config-local.json
        ;;
    *)
        params+=($key)
        ;;
esac
shift # get next argument
done
flutter run --debug --dart-define=FLUTTER_WEB_USE_SKIA=true -d chrome --dart-define-from-file=$CONFIG_FILE --extra-front-end-options=--dartdevc-module-format=ddc
