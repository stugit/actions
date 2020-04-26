#!/bin/bash -x 

# config
default_semvar_bump=${DEFAULT_BUMP:-minor}
with_v=${WITH_V:-false}
release_branches=${RELEASE_BRANCHES:-master}
custom_tag=${CUSTOM_TAG}
source=${SOURCE:-.}
dryrun=${DRY_RUN:-false}


# KT - add tag_prefix
tag_prefix=${TAG_PREFIX:-internal-}

cd ${GITHUB_WORKSPACE}/${source}

pre_release="true"
IFS=',' read -ra branch <<< "$release_branches"
for b in "${branch[@]}"; do
    echo "Is $b a match for ${GITHUB_REF#'refs/heads/'}"
    if [[ "${GITHUB_REF#'refs/heads/'}" =~ $b ]]
    then
        pre_release="false"
    fi
done

# KT - Allow override pre_release
pre_release=${PRE_RELEASE:-false}

echo "pre_release = $pre_release"

# fetch tags
git fetch --tags

# get latest tag that looks like a semver (with or without v)
#tag=$(git for-each-ref --sort=-v:refname --count=1 --format '%(refname)' refs/tags/[0-9]*.[0-9]*.[0-9]* refs/tags/v[0-9]*.[0-9]*.[0-9]* | cut -d / -f 3-)
tag=$(git for-each-ref --sort=-v:refname --count=1 --format '%(refname)'  refs/tags/${tag_prefix}[0-9]*.[0-9]*.[0-9]* refs/tags/${tag_prefix}v[0-9]*.[0-9]*.[0-9]* | cut -d / -f 3-)

tag_commit=$(git rev-list -n 1 $tag)

# get current commit hash for tag
commit=$(git rev-parse HEAD)

if [ "$tag_commit" == "$commit" ]; then
    echo "No new commits since previous tag. Skipping..."
    echo ::set-output name=tag::$tag
    exit 0
fi

# if there are none, start tags at 0.0.0
if [ -z "$tag" ]
then
    log=$(git log --pretty='%B')
    tag=0.0.0
else
    log=$(git log $tag..HEAD --pretty='%B')
    # remove tag prefix
    tag=${tag#"${tag_prefix}"}
fi

echo $log

# get commit logs and determine home to bump the version
# supports #major, #minor, #patch (anything else will be 'minor')
case "$log" in
    *#major* ) new=$(bash scripts/semver bump major $tag);;
    *#minor* ) new=$(bash scripts/semver bump minor $tag);;
    *#patch* ) new=$(bash scripts/semver bump patch $tag);;
    * ) new=$(bash scripts/semver bump `echo $default_semvar_bump` $tag);;
esac

# did we get a new tag?
if [ ! -z "$new" ]
then
	# prefix with 'v'
	if $with_v
	then
			new="v$new"
	fi

        # if not empty
	if [ ! -z $tag_prefix ]
	then
			new="${tag_prefix}${new}"
	fi

	if $pre_release
	then
			new="$new-${commit:0:7}"
	fi
fi

if [ ! -z $custom_tag ]
then
    new="$custom_tag"
fi

echo $new

# set outputs
echo ::set-output name=new_tag::$new

# use dry run to determine the next tag
if $dryrun
then
    echo ::set-output name=tag::$tag
    exit 0
fi 

echo ::set-output name=tag::$new


if $pre_release
then
    echo "This branch is not a release branch. Skipping the tag creation."
    exit 0
fi

# push new tag ref to github
dt=$(date '+%Y-%m-%dT%H:%M:%SZ')
full_name=$GITHUB_REPOSITORY
git_refs_url=$(jq .repository.git_refs_url $GITHUB_EVENT_PATH | tr -d '"' | sed 's/{\/sha}//g')

echo "$dt: **pushing tag $new to repo $full_name"

curl -s -X POST $git_refs_url \
-H "Authorization: token $GITHUB_TOKEN" \
-d @- << EOF
{
  "ref": "refs/tags/$new",
  "sha": "$commit"
}
EOF
