### Powerboards

Built on Meshagent

### Build

```
docker buildx bake default -f powerboards/powerboards-bake.hcl
```

This will produce an image named ```powerboards-ui:latest```


```
export IMAGE_TAG_PREFIX=my-prefix/
export POWERBOARDS_UI_TAG=v1
docker buildx bake default -f powerboards/powerboards-bake.hcl
```

This will produce an image named ```my-prefix/powerboards-ui:v1```