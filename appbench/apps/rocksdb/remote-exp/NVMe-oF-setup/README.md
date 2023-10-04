# NVME over Fabrics
Scripts for setting up NVME over Fabrics on Mellanox NIC. Tested on Cloudlab m510 machine. Use Cloudlab Profile `2-NVMe-Nodes`

## Terminology

- Target: Node with NVMe storage device.
- Client: Node taht wants to use NVMe device on target through RDMA.

## Usage

### On target:

```bash
# First format the NVMe partition that you want the client to use.
sudo mkfs.ext4 /dev/target_device

# Then replace ""/dev/nvme0n1" in target_setup.sh with the target block device.
# Also modify IP_ADDR in target_setup.sh to be the addr of the TARGET machine, and run the script.
sudo ./target_setup.sh
```



### On Client:

```bash
sudo ./client_setup.sh

# Replace NVME-SUBSYSTEM-NAME with the subsystem name setup in target_setup.sh.
# Replace ADDR with the IP address of the target RDMA interface.
nvme connect -t rdma -n NVME-SUBSYSTEM-NAME -a ADDR -s 4420
```

Use `sudo nvme list` to see the new remote NVMe device.

