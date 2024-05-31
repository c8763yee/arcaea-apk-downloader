#!/bin/bash

URL='https://webapi.lowiro.com/webapi/serve/static/bin/arcaea/apk'
REQUIRED_PACKAGES=(curl jq wget unzip)
REQUIRED_ASSETS=(img/grade songs)

# JSON SCHEMA:
# {
#  "success": true,
#  "value": {
#    "url": "https://arcaea-static.lowiro-cdn.net/YBaMFpe0aOWlw5uMTWV0s5cm8879tFZ9TXOLBbeuOmnJa8ZNmNsW6KA37mwRIx%2FljzQ488Yu6kkDYV61S6MYTiBh6kL58VMbdfN3RLmXYP7GR4SE02t2X%2Fk9DVWaOv47kqfKiP0tvJmM1Cs%3D?filename=arcaea_5.6.1c.apk",
#    "version": "5.6.1c"
#  }
#}

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
    echo $apk_version > /home/c8763yee/version.txt
}
function check_version(){
    latest_version=$(echo $webapi_response | jq -r '.value.version')
    if [[ -f version.txt ]]; then
        current_version=$(cat /home/c8763yee/version.txt)
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
        is_latest=false
    fi
}

function download_apk(){
    if [[ $is_latest == true ]]; then
        echo "You are already on the latest version."
        exit 0
    fi
    apk_url=$(echo $webapi_response | jq -r '.value.url')
    wget -O /tmp/arcaea.apk $apk_url
    write_version
}

function uncompress_apk(){
    if [[ ! -f /tmp/arcaea.apk ]]; then
        >&2 echo "APK not found."
        exit 1
    fi
    unzip -oqq /tmp/arcaea.apk -d /tmp/arcaea
}

function move_assets(){
    for asset in "${REQUIRED_ASSETS[@]}"; do
        if [[ ! -d /tmp/arcaea/assets/$asset ]]; then
            >&2 echo  "Asset $asset not found."
            exit 1
        fi
        # move assets to arcaea folder and make sure all user in this machine can access it
        # create folder if not exists
        if [[ ! -d /opt/arcaea/assets/$asset ]]; then
            sudo mkdir -p /opt/arcaea/assets/$asset
        fi
        # move into parent folder if $asset is a multi-level directory
        sudo cp -arf /tmp/arcaea/assets/$asset/* /opt/arcaea/assets/$asset/
    done
}

function cleanup(){
    rm -rf /tmp/arcaea{.apk,}
}

function restart_docker_containter(){
    docker restart bot file_api
}

function main(){
    get_apk_url && check_package && check_version 
    if [[ $is_latest == true ]]; then
        echo "You are already on the latest version."
        exit 0
    else
        download_apk && uncompress_apk && move_assets && cleanup && restart_docker_containter
    fi
}

echo "Welcome to Arcaea downloader. This script will download the latest version of Arcaea."
main
