#!/bin/bash

# Modified for IS-04, which uses RAML 0.8 in old versions, 1.0 in new ones

if [ ! -d node_modules/.bin ]; then
    echo "fatal: Cannot find build tools (have you done 'make build-tools?')"
    exit 1
fi

PATH=$PWD/node_modules/.bin:$PATH

function extract {
    checkout=$1
    target_dir=$2
    echo "Extracting documentation from $checkout into $target_dir"
    mkdir "$target_dir"
    cd source-repo
        echo "Checking out $checkout..."
        git checkout "$checkout"
        if [ -d docs ]; then
            cp -r docs "../$target_dir"
        fi
        if [ -d APIs ]; then
            cd APIs
                # Is this branch or tag using RAML 0.8? If so treat differently
                if grep -q '^#%RAML *0.8' *.raml; then
                    echo "This looks like RAML 0.8"
                    for i in *.raml; do
                        echo "Generating HTML from $i..."
                        raml2html-3 $i > "${i%%.raml}.html"
                    done 
                else
                    echo "This looks like RAML 1.0 or later"
                    echo "NB: including workaround for how v6+ of raml2html deals with \$ref and schemas/ dir"
                    perl -pi.orig -e 's=("\$ref": ")(.*)(\.json)=$1schemas/$2$3=' schemas/*.json
                    for i in *.raml; do
                        echo "Generating HTML from $i..."
                        raml2html $i > "${i%%.raml}.html"
                    done
                    for i in schemas/*.json.orig; do
                        mv "$i" "${i%%.orig}"
                    done
                fi

                mkdir "../../$target_dir/html-APIs"
                mv *.html "../../$target_dir/html-APIs/"
                if [ -d schemas ]; then
                    echo "Linting schemas..."
                    jsonlint -v schemas/*.json
                    echo "Copying schemas..."
                    mkdir "../../$target_dir/html-APIs/schemas"
                    cp schemas/*.json "../../$target_dir/html-APIs/schemas"
                fi
                cd ..
        fi
        if [ -d examples ]; then
            echo "Linting examples..."
            jsonlint -v examples/*.json
            echo "Copying examples..."
            cp -r examples "../$target_dir"
        fi
    cd ..
}

# Find out which branches and tags will be shown
. ./get-config.sh

mkdir branches
for branch in $(cd source-repo; git branch -r | sed 's:origin/::' | grep -v HEAD | grep -v gh-pages); do
    if [[ "$branch" =~ $SHOW_BRANCHES ]]; then
        extract "$branch" "branches/$branch"
    else
        echo Skipping branch $branch
    fi
done

mkdir tags
for tag in $(cd source-repo; git tag); do
    if [[ "$tag" =~ $SHOW_TAGS ]]; then
        extract "tags/$tag" "tags/$tag"
    else
        echo Skipping tag $tag
    fi
done
