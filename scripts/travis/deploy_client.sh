#!/bin/bash

# Copyright 2020 The SQLFlow Authors. All rights reserved.
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

set -e

# For more informaiton about deployment with Travis CI, please refer
# to the file header of deploy_docker.sh

if [[ "$TRAVIS_PULL_REQUEST" != "false" ]]; then
    echo "Skip deployment on pull request"
    exit 0
fi

# Figure out the tag to push sqlflow:ci.
if [[ "$TRAVIS_BRANCH" == "develop" ]]; then
    if [[ "$TRAVIS_EVENT_TYPE" == "cron" ]]; then
        RELEASE_TAG="nightly"
    else
        RELEASE_TAG="latest"
    fi
elif [[ "$TRAVIS_TAG" != "" ]]; then
    RELEASE_TAG="$TRAVIS_TAG"
else
    echo "Cannot figure out Docker image tag."
    exit 1
fi

echo "Verify Go is installed ..."
go env

echo "Verify protoc is installed ..."
protoc --version

echo "Install goyacc and protoc-gen-go ..."
go get \
   github.com/golang/protobuf/protoc-gen-go@v1.3.3 \
   golang.org/x/tools/cmd/goyacc
sudo cp $GOPATH/bin/* /usr/local/bin/

echo "Build cmd/sqlflow into /tmp ..."
cd $TRAVIS_BUILD_DIR
go generate ./...
GOBIN=/tmp go install ./cmd/sqlflow

echo "Install Qiniu client for $TRAVIS_OS_NAME ..."
case "$TRAVIS_OS_NAME" in
    linux) F="qshell-linux-x64-v2.4.1" ;;
    windows) F="qshell-windows-x64-v2.4.1.exe" ;;
    osx) F="qshell-darwin-x64-v2.4.1" ;;
esac
curl -so $F.zip http://devtools.qiniu.com/$F.zip
unzip $F.zip # Get $F
sudo mv $F /usr/local/bin/qshell

echo "Publish /tmp/sqlflow to Qiniu Object Storage ..."
qshell account "$QINIU_AK" "$QINIU_SK" "wu"
qshell rput sqlflow-release \
       $RELEASE_TAG/$TRAVIS_OS_NAME/sqlflow
       /tmp/sqlflow