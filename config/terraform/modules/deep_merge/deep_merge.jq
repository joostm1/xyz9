def deep_merge($base; $override):
  if ($base | type) == "object" and ($override | type) == "object" then
    reduce (($base + $override) | keys_unsorted[]) as $key ({};
      .[$key] =
        if ($base | has($key)) and ($override | has($key)) then
          deep_merge($base[$key]; $override[$key])
        elif ($override | has($key)) then
          $override[$key]
        else
          $base[$key]
        end
    )
  else
    $override
  end;

def sort_keys:
  if type == "object" then
    to_entries
    | sort_by(.key)
    | map({key: .key, value: (.value | sort_keys)})
    | from_entries
  elif type == "array" then
    map(sort_keys)
  else
    .
  end;

{
  result: (deep_merge((.base | fromjson); (.override | fromjson)) | sort_keys | tojson)
}
