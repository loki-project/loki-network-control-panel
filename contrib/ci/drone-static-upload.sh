#!/usr/bin/env bash

# Script used with Drone CI to upload build artifacts (because specifying all this in
# .drone.jsonnet is too painful).

set -o errexit

if [ -z "$SSH_KEY" ]; then
    echo -e "\n\n\n\e[31;1mUnable to upload artifact: SSH_KEY not set\e[0m"
    # Just warn but don't fail, so that this doesn't trigger a build failure for untrusted builds
    exit 0
fi

echo "$SSH_KEY" >ssh_key
set -o xtrace  # Don't start tracing until *after* we write the ssh key
chmod 600 ssh_key

os="$DRONE_STAGE_OS-$DRONE_STAGE_ARCH"
if [ -n "$WINDOWS_BUILD_NAME" ]; then
    os="windows-$WINDOWS_BUILD_NAME"
fi

if [ -n "$DRONE_TAG" ]; then
    # For a tag build use something like `lokinet-linux-amd64-v1.2.3`
    base="lokinet-gui-$os-$DRONE_TAG"
else
    # Otherwise build a length name from the datetime and commit hash, such as:
    # lokinet-linux-amd64-20200522T212342Z-04d7dcc54
    base="lokinet-gui-$os-$(date --date=@$DRONE_BUILD_CREATED +%Y%m%dT%H%M%SZ)-${DRONE_COMMIT:0:9}"
fi

if [ -e lokinet-gui.exe ]; then
    cp -av lokinet-gui.exe ../gui
    rm -rf ../gui/.git
    rm ../gui/README
    echo "if you do not have a GPU installed or are using the basic video driver (vgasave, basicdisplay, rdpdd) \
    rename 'opengl32sw.dll' to 'opengl32.dll' before starting up the lokinet gui. -rick" > ../gui/README
    # zipit up yo
    archive="$base.zip"
    zip -r "$archive" ../gui
else
    mkdir -v "$base"
    cp -av lokinet-gui "$base"
    # tar dat shiz up yo
    archive="$base.tar.xz"
    tar cJvf "$archive" "$base"
fi

upload_to="builds.lokinet.dev/${DRONE_REPO// /_}/${DRONE_BRANCH// /_}"

# sftp doesn't have any equivalent to mkdir -p, so we have to split the above up into a chain of
# -mkdir a/, -mkdir a/b/, -mkdir a/b/c/, ... commands.  The leading `-` allows the command to fail
# without error.
upload_dirs=(${upload_to//\// })
mkdirs=
dir_tmp=""
for p in "${upload_dirs[@]}"; do
    dir_tmp="$dir_tmp$p/"
    mkdirs="$mkdirs
-mkdir $dir_tmp"
done

sftp -i ssh_key -b - -o StrictHostKeyChecking=off drone@builds.lokinet.dev <<SFTP
$mkdirs
put $archive $upload_to
SFTP

set +o xtrace

echo -e "\n\n\n\n\e[32;1mUploaded to https://${upload_to}/${archive}\e[0m\n\n\n"

