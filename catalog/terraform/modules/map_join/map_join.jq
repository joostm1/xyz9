def value_at($path):
  reduce ($path | split("."))[] as $part (. ; .[$part]);

def match_value($entry; $path):
  if $path == "key" then $entry.key else $entry.value | value_at($path) end;

def output_object($left; $right):
  $left.value
  + (if $right == null then {} else $right.value end)
  + {
      left_key: $left.key,
      right_key: (if $right == null then null else $right.key end)
    };

def generated_key($entry; $key_attrs):
  [$key_attrs[] as $attr | ($entry[$attr] | tostring)] | join("-") | ascii_downcase;

(.key_attrs | fromjson) as $key_attrs
| (.join_type) as $join_type
| (.left | fromjson) as $left
| (.right | fromjson) as $right
| (.left_match_attr) as $left_match_attr
| (.right_match_attr) as $right_match_attr
| [
    $left | to_entries[] as $left_entry
    | ([$right | to_entries[] | select(match_value($left_entry; $left_match_attr) == match_value(.; $right_match_attr))]) as $right_matches
    | (if ($right_matches | length) > 0 then $right_matches elif $join_type == "left" then [null] else [] end)[] as $right_entry
    | output_object($left_entry; $right_entry) as $entry
    | $entry + {key: generated_key($entry; $key_attrs)}
  ] as $entries
| ($entries | map(.key) | unique | length) as $unique_key_count
| if $unique_key_count != ($entries | length) then
    error("map_join generated duplicate keys")
  else
    {
      entries: ($entries | tojson),
      by_key: ($entries | map({key: .key, value: .}) | from_entries | tojson)
    }
  end
