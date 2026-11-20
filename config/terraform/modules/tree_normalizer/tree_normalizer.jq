def normalized_segment($singular_segments):
  . as $segment
  | ($singular_segments[$segment] // $segment);

def normalized_path($singular_segments):
  map(normalized_segment($singular_segments));

def without_collections($collection_keys):
  if type == "object" then
    with_entries(.key as $key | select(($collection_keys | index($key)) == null))
  else
    .
  end;

def parent_ref:
  {
    key: .key,
    local_key: .local_key,
    collection_key: .collection_key,
    collection_segment: .collection_segment,
    path: .path,
    normalized_path: .normalized_path,
    value: .value
  };

def entry($collection_key; $singular_segments; $collection_keys; $path; $parent_path; $local_key; $key_segments; $parents; $ancestors; $parent_key; $parent_collection_key; $value):
  ($collection_key | normalized_segment($singular_segments)) as $collection_segment
  | ($path | normalized_path($singular_segments)) as $normalized_path
  | ($key_segments | join("-") | ascii_downcase) as $key
  | {
      key: $key,
      local_key: $local_key,
      collection_key: $collection_key,
      collection_segment: $collection_segment,
      path: $path,
      normalized_path: $normalized_path,
      parent_path: $parent_path,
      parent_key: $parent_key,
      parent_collection_key: $parent_collection_key,
      parents: $parents,
      ancestors: $ancestors,
      value: ($value | without_collections($collection_keys))
    };

def walk_tree($collection_keys; $singular_segments; $path; $parents; $ancestors; $key_segments; $parent_key; $parent_collection_key):
  if type != "object" then
    []
  else
    . as $object
    | (
        $collection_keys
        | map(. as $collection_key
          | if ($object[$collection_key]? | type) == "object" then
              $object[$collection_key]
              | to_entries
              | map(
                  .key as $local_key
                  | .value as $value
                  | ($path + [$collection_key, $local_key]) as $entry_path
                  | ($key_segments + [$local_key]) as $entry_key_segments
                  | entry($collection_key; $singular_segments; $collection_keys; $entry_path; $path; $local_key; $entry_key_segments; $parents; $ancestors; $parent_key; $parent_collection_key; $value) as $entry
                  | [$entry] + (
                      $value
                      | walk_tree(
                          $collection_keys;
                          $singular_segments;
                          $entry_path;
                          ($parents + {($collection_key): ($entry | parent_ref)});
                          ($ancestors + [($entry | parent_ref)]);
                          $entry_key_segments;
                          $entry.key;
                          $collection_key
                        )
                    )
                )
              | add // []
            else
              []
            end
        )
        | add // []
      ) + (
        $object
        | to_entries
        | map(.key as $key | select(($collection_keys | index($key)) == null) | .value | walk_tree($collection_keys; $singular_segments; $path + [$key]; $parents; $ancestors; $key_segments + [$key]; $parent_key; $parent_collection_key))
        | add // []
      )
  end;

(.collection_keys | fromjson) as $collection_keys
| (.singular_segments | fromjson) as $singular_segments
| ((.tree | fromjson) | walk_tree($collection_keys; $singular_segments; []; {}; []; []; null; null)) as $entries
| {
    entries: ($entries | tojson),
    by_key: ($entries | map({key: .key, value: .}) | from_entries | tojson),
    by_collection: (
      reduce $collection_keys[] as $collection_key ({};
        . + {
          ($collection_key): (
            $entries
            | map(select(.collection_key == $collection_key) | {key: .key, value: .})
            | from_entries
          )
        }
      )
      | tojson
    )
  }
