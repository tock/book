# Packer-based Tutorial / Development VM Image

Build instructions:

1. Install VirtualBox and ensure that you can run a VM as an unprivileged user.
2. Install HashiCorp Packer.
3. Run `packer build packer.json`, and grab a cup of coffee. It'll download a
   large Ubuntu server image, and then magically type some boot arguments. The
   Ubuntu installer may take about 10 minutes, depending on your hardware and
   network connection.
4. If it fails during installation because the installer crashed, there was
   likely an intermittent network issue trying to download packages. Quit Packer
   (`C-c`), wait until it finishes cleaning up, and then try again.
5. `mv output-virtualbox-iso tock-dev-vm`
6. `zip -r tock-dev-vm.zip tock-dev-vm`, avoid using .tar.\* for Windows
