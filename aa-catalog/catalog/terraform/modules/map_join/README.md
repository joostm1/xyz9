# map_join

Joins two keyed maps of objects by matching one attribute from each side, then emits a keyed map suitable for `for_each`.

The module compares `left_match_attr` with `right_match_attr`. It defaults to an inner join: only matching pairs are emitted. Set `join_type = "left"` to emit every left row, with right-side fields set to `null` when there is no match.

Inputs:

- `left`: left keyed map of objects
- `right`: right keyed map of objects
- `join_type`: `inner` or `left`, defaults to `inner`
- `left_match_attr`: attribute path on each left object used for matching, defaults to `key`
- `right_match_attr`: attribute path on each right object used for matching
- `key_attrs`: output fields used to generate each result key

## Example: Fruit Eaters

Input maps:

```hcl
locals {
  fruits = {
    apple = {
      color = "red"
      avg_calories = 95
    }
    banana = {
      avg_calories = 105
      color = "yellow"
    }
  }
  animals = {
    monkey = {
      preferred_food = "banana"
    }
    horse = {
      preferred_food = "apple"
    }
    panda = {
      preferred_food = "bamboo"
    }
  }
}
```

Module call:

```hcl
module "fruit_eaters" {
  source           = "../../org/terraform/modules/map_join"
  left             = local.animals
  right            = local.fruits
  left_match_attr  = "preferred_food"
  right_match_attr = "key"
  key_attrs        = ["left_key"]
}
```

Matching:

- `horse.preferred_food == apple`
- `monkey.preferred_food == banana`
- `panda.preferred_food` has no matching fruit, so it is not emitted by the default inner join

The output object is `merge(left.value, right.value)` plus `left_key`, `right_key`, and generated `key` metadata.

`module.fruit_eaters.by_key`:

```hcl
{
  horse = {
    key            = "horse"
    left_key       = "horse"
    right_key      = "apple"
    color          = "red"
    avg_calories   = 95
    preferred_food = "apple"
  }
  monkey = {
    key            = "monkey"
    left_key       = "monkey"
    right_key      = "banana"
    avg_calories   = 105
    color          = "yellow"
    preferred_food = "banana"
  }
}
```
