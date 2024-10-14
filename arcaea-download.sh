#!/bin/bash

URL='https://webapi.lowiro.com/webapi/serve/static/bin/arcaea/apk'
REQUIRED_PACKAGES=(curl jq wget unzip)
REQUIRED_ASSETS=(img/{grade,bg} songs)

function write_diff_after_update(){
  echo "Diff after updated from $current_version to $latest_version"
  # compare file and content between downloaded files and current files
  if [[ ! -d $HOME/arcaea-download/diff ]]; then
    mkdir -p $HOME/arcaea-download/diff
  fi
  diff -bur /opt/arcaea /tmp/arcaea | tee $HOME/arcaea-download/diff/diff-$current_version-$latest_version.diff
}

function check_package(){
    for package in "${REQUIRED_PACKAGES[@]}"; do
        if [[ ! $(which "$package") ]]; then
            >&2 echo "Please install $package using your package manager."
            exit 1
        fi
    done
}
function get_apk_url(){
    webapi_response=$(curl -s $URL | jq)
    # check if failed to get download link
    if [[ $(echo $webapi_response | jq -r '.success') == 'false' ]]; then
        >&2 echo "Failed to get download link."
        exit 1
    fi
}
function write_version(){
    apk_version=$(echo $webapi_response | jq -r '.value.version')
    echo $apk_version > $HOME/version.txt
}
function check_version(){
    latest_version=$(echo $webapi_response | jq -r '.value.version')
    if [[ -f version.txt ]]; then
        current_version=$(cat $HOME/version.txt)
        if [[ $latest_version == "$current_version" ]]; then
            echo "You are already on the latest version."
            is_latest=true
            exit 
        elif [[ $latest_version != "$current_version" ]]; then
            echo "New version available: $latest_version, current version: $current_version."
            is_latest=false
        fi
    else
        echo "version.txt not found."
        current_version="0.0.0"
        is_latest=false
    fi
}

function download_apk(){
    if [[ $is_latest == true ]]; then
        echo "You are already on the latest version."
        exit 0
    fi
    apk_url=$(echo $webapi_response | jq -r '.value.url')
    wget -qO /tmp/arcaea-$latest_version.apk $apk_url
}

function uncompress_apk(){
    if [[ ! -f /tmp/arcaea-$latest_version.apk ]]; then
        >&2 echo "APK not found."
        exit 1
    fi
    unzip -oqq /tmp/arcaea-$latest_version.apk -d /tmp/arcaea_apk
    mkdir -p $HOME/arcaea-download/tree
    tree /tmp/arcaea_apk > $HOME/arcaea-download/tree/$latest_version.txt
}

function move_assets(){
    for asset in "${REQUIRED_ASSETS[@]}"; do
        if [[ ! -d /tmp/arcaea_apk/assets/$asset ]]; then
            >&2 echo  "Asset $asset not found."
            exit 1
        else
            sudo mkdir -p /tmp/arcaea/assets/$asset
            echo "Copy asset from /tmp/arcaea_apk/assets/$asset to /tmp/arcaea/assets/$asset"
            sudo cp -arf /tmp/arcaea_apk/assets/$asset/* /tmp/arcaea/assets/$asset/
        fi
        # move assets to arcaea folder and make sure all user in this machine can access it
        # create folder if not exists
    done

    sudo mkdir -p /opt/arcaea
    write_diff_after_update
    sudo cp -arf /tmp/arcaea/assets /opt/arcaea
}

function cleanup(){
    sudo rm -rf /tmp/arcaea{{-${latest_version}.,_}apk,}
}

function main(){
    get_apk_url && check_package && check_version 
    if [[ $is_latest == true ]]; then
        echo "You are already on the latest version."
        exit 0
    else
        download_apk && uncompress_apk && move_assets &&  
        cleanup && write_version
    fi
}

echo "Welcome to Arcaea downloader. This script will download the latest version of Arcaea."
main
