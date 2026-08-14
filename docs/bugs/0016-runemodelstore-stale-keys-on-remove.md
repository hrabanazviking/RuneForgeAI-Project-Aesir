# Bug Report: `RuneModelStore.remove_model` Retains Stale Keys in `model_keys`

**Bug ID**: 0016
**Title**: `RuneModelStore.remove_model` pops manifest from catalog but retains stale key string in `model_keys` list
**Component**: `cli/manifest.mojo`
**Status**: Resolved

## Description
In `cli/manifest.mojo`, when `remove_model(name)` is called on `RuneModelStore`, it pops the model manifest entry from `self.catalog`:
```mojo
_ = self.catalog.pop(search_name)
```
However, it fails to remove `search_name` from `self.model_keys`. While `list_models()` guards against missing catalog entries (`if key in self.catalog`), repeated addition and deletion of models causes `self.model_keys` to accumulate stale key strings.

## Additive / Clean Fix Applied
Updated `RuneModelStore.remove_model` to reconstruct `self.model_keys` excluding the deleted `search_name`, keeping `self.model_keys` strictly in sync with `self.catalog`.
