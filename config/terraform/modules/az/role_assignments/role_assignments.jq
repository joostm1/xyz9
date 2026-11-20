def group_key($entra_groups; $path):
  ($path | join("-")) as $full_key
  | ($path[1:] | join("-")) as $without_root_key
  | ($path | map(select(. != "locations")) | join("-")) as $no_locations
  | ($path[1:] | map(select(. != "locations")) | join("-")) as $no_locations_without_root
  | if $entra_groups[$full_key] then
      $full_key
    elif ($path | length) > 1 and $entra_groups[$without_root_key] then
      $without_root_key
    elif $entra_groups[$no_locations] then
      $no_locations
    elif $entra_groups[$no_locations_without_root] then
      $no_locations_without_root
    else
      error("No Entra group found for role assignment path " + ($path | join(".")))
    end;

def flatten_role_assignments($entra_groups; $path):
  to_entries
  | map(
      .key as $key
      | .value as $value
      | if (($value | type) == "object" and (($value | to_entries | all(.value | type == "boolean")))) then
          (group_key($entra_groups; $path + [$key])) as $group_key
          | $value
          | to_entries
          | map(select(.value == true))
          | map({
              name: (($group_key + "-" + .key) | ascii_downcase | gsub("[[:space:]]+"; "-")),
              roledefinition_name: .key,
              group_key: $group_key
            })
        elif ($value | type) == "object" then
          $value | flatten_role_assignments($entra_groups; $path + [$key])
        else
          []
        end
    )
  | add // [];

(.entra_groups | fromjson) as $entra_groups
| {
    role_assignments: (
      (.role_assignments | fromjson)
      | flatten_role_assignments($entra_groups; [])
      | tojson
    )
  }
