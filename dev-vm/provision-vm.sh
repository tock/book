#!/usr/bin/env bash

echo "Provisioning Tock development VM..."
cd /home/tock/

git clone https://github.com/tock/tock ./tock
git clone https://github.com/tock/libtock-c ./libtock-c
git clone https://github.com/tock/libtock-rs ./libtock-rs

echo "Installing rustup"
curl https://sh.rustup.rs -sSf | sh -s -- -y

echo "Installing Tockloader"
sudo pip3 install tockloader
