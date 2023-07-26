#!/usr/bin/env bash

JLINK_VERSION="766"
JLINK_URL="https://www.segger.com/downloads/jlink/JLink_Linux_V${JLINK_VERSION}_x86_64.deb"

cat <<EOF
Use of the "SEGGER JLink Software and Documentation pack" requires the
acceptance of the following licenses:

  - SEGGER Downloads Terms of Use
    (${JLINK_URL})
  - SEGGER Software Licensing
    (https://www.segger.com/purchase/licensing/)

This script can automatically download and install the JLink software
for you, but you need to agree to the terms and conditions of the
above licenses.

If you agree to proceed, we will pass \`accept_license_agreement=accepted\`
along with the request to download the software.

EOF

read -p "Do you want to proceed and accept the licenses? (y/N) " ACCEPT_LICENSE_PROMPT

if [ "$ACCEPT_LICENSE_PROMPT" != "y" ]; then
	echo "Aborting."
	exit 1
fi

echo "Downloading the JLink software..."
curl -o/tmp/jlink.deb --data accept_license_agreement=accepted "${JLINK_URL}"

echo "Installing the JLink software..."
sudo dpkg -i /tmp/jlink.deb

echo "Reloading udev..."
sudo udevadm control --reload-rules
sudo udevadm trigger
