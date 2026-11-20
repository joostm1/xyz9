# scope_enumerator

Enumerates a nested object by expanding list values found under a configurable key.

## Inputs

| Name                   | Type          | Required | Default | Description                                                                                                     |
| ---------------------- | ------------- | -------- | ------- | --------------------------------------------------------------------------------------------------------------- |
| `tree`                 | `any`         | no       | `{}`    | Nested object to walk. Every object containing `enum_key` as a list produces enumerated entries.                |
| `enum_key`             | `string`      | yes      | n/a     | Object key containing the list values to expand.                                                                |
| `enum_value_name`      | `string`      | yes      | n/a     | Name of the output attribute that stores each expanded value from `enum_key`.                                   |
| `segment_translations` | `map(string)` | no       | `{}`    | Optional path segment translations used when generating keys. Unmapped path segments keep their original value. Translate a segment to `""` to omit it from keys and labels. |

For example, with `enum_key = "roles"`, the path `datasets.nyt.roles = ["analyst"]` produces `datasets-nyt-analyst` by default. With `segment_translations = { datasets = "dataset" }`, the same path produces `dataset-nyt-analyst`.

## Outputs

| Name      | Type           | Description                                               |
| --------- | -------------- | --------------------------------------------------------- |
| `entries` | `list(object)` | Enumerated entries as a list.                             |
| `by_key`  | `map(object)`  | Enumerated entries keyed by each entry's generated `key`. |

## Entry Shape

Each output entry has these fields:

| Field               | Type           | Description                                                                                        |
| ------------------- | -------------- | -------------------------------------------------------------------------------------------------- |
| `key`               | `string`       | Generated key from `normalized_path + [<enum value>]`, joined with `-` and lowercased.             |
| `path`              | `list(string)` | Original path to the object containing `enum_key`.                                                 |
| `normalized_path`   | `list(string)` | Path after applying `segment_translations`.                                                        |
| `path_key`          | `string`       | `normalized_path` joined with `-` and lowercased.                                                  |
| `path_label`        | `string`       | `normalized_path` joined with `-` without lowercasing.                                             |
| `enum_key`          | `string`       | The input `enum_key`.                                                                              |
| `<enum_value_name>` | `any`          | One expanded value from the list at `enum_key`. The field name is configured by `enum_value_name`. |
| `name`              | `string`       | Same value as `key`.                                                                               |

## Example: Animal Foods

Input tree:

```hcl
locals {
  animals = {
    monkey = {
      foods = {
        preferred = ["banana", "mango"]
      }
    }
    horse = {
      foods = {
        preferred = ["apple", "carrot"]
      }
    }
    panda = {
      foods = {
        preferred = ["bamboo"]
      }
    }
  }
}
```

Module call:

```hcl
module "animal_foods" {
  source          = "../../org/terraform/modules/scope_enumerator"
  tree            = local.animals
  enum_key        = "preferred"
  enum_value_name = "preferred_food"
}
```

`module.animal_foods.by_key`:

```hcl
{
  monkey-foods-banana = {
    key             = "monkey-foods-banana"
    path            = ["monkey", "foods"]
    normalized_path = ["monkey", "foods"]
    path_key        = "monkey-foods"
    path_label      = "monkey-foods"
    enum_key        = "preferred"
    preferred_food  = "banana"
    name            = "monkey-foods-banana"
  }
  monkey-foods-mango = {
    key             = "monkey-foods-mango"
    path            = ["monkey", "foods"]
    normalized_path = ["monkey", "foods"]
    path_key        = "monkey-foods"
    path_label      = "monkey-foods"
    enum_key        = "preferred"
    preferred_food  = "mango"
    name            = "monkey-foods-mango"
  }
  horse-foods-apple = {
    key             = "horse-foods-apple"
    path            = ["horse", "foods"]
    normalized_path = ["horse", "foods"]
    path_key        = "horse-foods"
    path_label      = "horse-foods"
    enum_key        = "preferred"
    preferred_food  = "apple"
    name            = "horse-foods-apple"
  }
  horse-foods-carrot = {
    key             = "horse-foods-carrot"
    path            = ["horse", "foods"]
    normalized_path = ["horse", "foods"]
    path_key        = "horse-foods"
    path_label      = "horse-foods"
    enum_key        = "preferred"
    preferred_food  = "carrot"
    name            = "horse-foods-carrot"
  }
  panda-foods-bamboo = {
    key             = "panda-foods-bamboo"
    path            = ["panda", "foods"]
    normalized_path = ["panda", "foods"]
    path_key        = "panda-foods"
    path_label      = "panda-foods"
    enum_key        = "preferred"
    preferred_food  = "bamboo"
    name            = "panda-foods-bamboo"
  }
}
```

With explicit segment translations:

```hcl
module "animal_food" {
  source          = "../../org/terraform/modules/scope_enumerator"
  tree            = local.animals
  enum_key        = "preferred"
  enum_value_name = "preferred_food"
  segment_translations = {
    foods = "food"
  }
}
```

The path segment `foods` is translated in generated keys and labels:

```hcl
{
  monkey-food-banana = {
    key             = "monkey-food-banana"
    path            = ["monkey", "foods"]
    normalized_path = ["monkey", "food"]
    path_key        = "monkey-food"
    path_label      = "monkey-food"
    enum_key        = "preferred"
    preferred_food  = "banana"
    name            = "monkey-food-banana"
  }
  # ...
}
```

## Console

To inspect the example output interactively, place the `locals` and `module "animal_foods"` example in a temporary Terraform root module, run `terraform init`, then open `terraform console`.

Useful console expressions:

```hcl
module.animal_foods.by_key
module.animal_foods.entries
keys(module.animal_foods.by_key)
module.animal_foods.by_key["monkey-foods-banana"]
```

For the translated variant, inspect the translated key instead:

```hcl
module.animal_food.by_key["monkey-food-banana"]
```
