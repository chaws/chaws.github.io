#!/bin/bash

set -eu


basedir="$(readlink -f "$(dirname $0)")"
tmpdir="$basedir"/tmp
mkdir -p "$tmpdir"


dockerfile="$tmpdir"/Dockerfile
(
  cat $basedir/Dockerfile
  echo "RUN groupadd -g $(id -g) $(id -gn) && \\"
  echo "    useradd -m -u $(id -u) -g $(id -g) -s /bin/bash ${USER}"
  echo "USER ${USER}"

  echo "WORKDIR /site"
  echo 'CMD ["bash"]'
) > "$dockerfile"

no_cache=${DOCKER_NO_CACHE-}

docker build $no_cache -t chaws-site -f "$dockerfile" .

extra_volumes=""
for v in $HOME/.gitconfig $HOME/.config/git; do
  if [ -e "$v" ]; then
    extra_volumes="$extra_volumes --volume=$v:$v"
  fi
done

PORT=${PORT:-4000}

exec docker run \
  --env=PORT=${PORT} \
  --publish=${PORT}:${PORT} \
  --volume="$basedir":/site \
  --name=chaws-site \
  --hostname=chaws-site \
  $extra_volumes \
  --rm \
  -it chaws-site bundle exec jekyll serve --host 0.0.0.0 --baseurl=""
