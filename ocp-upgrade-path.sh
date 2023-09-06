function ocp-upgrade-paths() {
  version=$1
  for channel in stable fast candidate ; do
      echo "=== $channel-$version ==="
      curl -sH 'Accept: application/json' "https://api.openshift.com/api/upgrades_info/v1/graph?channel=$channel-$version" | jq -r '[.nodes[].version] | sort | unique[]'
  done
}

function ocp-version-info() {
  channel=$1
  version=$2
  major=$(echo $version | awk -F '.' '{print $1 "." $2}')
  minor=$(echo $version | awk -F '.' '{print $NF}')
  echo "Checking for $channel and major $major and minor $minor"
  url="https://api.openshift.com/api/upgrades_info/v1/graph?channel=$channel-$major&x86_64'"
  echo $url
  curl -sH "Accept:application/json" $url | jq ".nodes[] | select(.version == \"$version\")"
}