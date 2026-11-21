def normalized_segment($segment_translations):
  . as $segment
  | ($segment_translations[$segment] // $segment);

def normalized_path($segment_translations):
  map(normalized_segment($segment_translations))
  | map(select(. != ""));

def entry($enum_key; $enum_value_name; $segment_translations; $path; $value):
  ($path | normalized_path($segment_translations)) as $normalized_path
  | (($normalized_path + [$value]) | join("-") | ascii_downcase) as $key
  | {
      key: $key,
      path: $path,
      normalized_path: $normalized_path,
      path_key: (($normalized_path | join("-")) | ascii_downcase),
      path_label: ($normalized_path | join("-")),
      enum_key: $enum_key,
      name: $key
    }
    + {($enum_value_name): $value};

def enumerate_scopes($enum_key; $enum_value_name; $segment_translations; $path):
  if type != "object" then
    []
  else
    (if (.[$enum_key]? | type) == "array" then
      [.[$enum_key][] | entry($enum_key; $enum_value_name; $segment_translations; $path; .)]
    else
      []
    end) + (
      to_entries
      | map(.key as $key | select($key != $enum_key) | .value | enumerate_scopes($enum_key; $enum_value_name; $segment_translations; $path + [$key]))
      | add // []
    )
  end;

(.enum_key) as $enum_key
| (.enum_value_name) as $enum_value_name
| (.segment_translations | fromjson) as $segment_translations
| ((.tree | fromjson) | enumerate_scopes($enum_key; $enum_value_name; $segment_translations; [])) as $entries
| {
    entries: ($entries | tojson),
    by_key: ($entries | map({key: .key, value: .}) | from_entries | tojson)
  }
