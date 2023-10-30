### Artifact Evaluation Submission for CrossPrefetch [ASPLOS '24]

This repository contains the artifact for reproducing our ASPLOS '24 paper "CrossPrefetch: Accelerating I/O Prefetching for Modern Storage".

### Directory structure
```
.
├── README.md
├── appbench/apps       # Application workloads
├── linux-5.14.0        # Modified Linux kernel (Cross-OS)
├── results             # Folder with all results 
├── scripts             # All scripts for setup and benchmark running
└── shared_libs/simple_prefetcher    # The user-level library (Cross-Lib)
```

### Setup Environment

(1) First, we encourage users to use the NSF CloudLab Clemson node (`r6525`), which has 128 CPU cores and a Samsung NVMe SSD. We have created a Cloudlab profile "r6525" to create the instance easily. If `r6525` machine is unavailable, please refer to the [resource reservation](http://docs.cloudlab.us/reservations.html) to reserve the node. 

(2) Cloudlab Machine Setup

First, you would have to set up a filesystem and mount it on an NVMe SSD

```
sudo mkfs.ext4 /dev/nvme0n1
mkdir ~/ssd; sudo mount /dev/nvme0n1 ~/ssd
cd ~/ssd; sudo chown $USER .
```

Now, get the appropriate repo.
```
cd ssd
git clone https://github.com/RutgersCSSystems/crossprefetch-asplos24-artifacts
cd crossprefetch-asplos24-artifacts
```

You now have the repo. Before compiling and setting up things, let's set the environmental variable and install the required packages by using the following commands.

```
source ./scripts/setvars.sh
# Let's install the Debian packages
scripts/install_packages.sh
```

### Compile and install modified Linux kernel

First, compile and install the CrossPrefetch OS components.

```
cd $BASE/linux-5.14.0
## This will produce and install the modified kernel
./compile_modified_deb.sh 
sudo reboot ## This will reboot the node with the new Linux. 
```

After rebooting, we need to mount the storage again.

```
sudo mount /dev/nvme0n1 ~/ssd
cd ~/ssd; sudo chown $USER .
```
### Run Experiments

We need **setup the environment variables and install the user-level library first before running any experiments**. 

The following script will set the environment variables and install the user-level library.
```
# Navigate to the source folder
cd ~/ssd/crossprefetch-asplos24-artifacts
source ./scripts/setvars.sh
cd $BASE/shared_libs/simple_prefetcher/
./compile.sh
```

#### Basic Run (Shorter duration: less than 1 hour)

##### Running RocksDB + YCSB
First, we will start with running medium workloads. As a first step, we will start running RocksDB with a real-world YCSB workload.  

Before compiling, we must ensure the environmental variables are set by `set_vars.sh`.

 The following commands will install the necessary packages to compile RocksDB with YCSB. 
```
cd $BASE/appbench/apps/RocksDB-YCSB
./compile.sh
```

We run YCSB with multiple configurations of RocksDB by varying APPonly (i.e.,
application-controlled prefetching, which is a Vanilla RocksDB), OSonly (OS
controlled) by turning off application prefetch operations and Cross-prefetch
configurations for various thread counts and workloads.

Then run YCSB, extract, and see the results
```
cd $BASE/appbench/apps/RocksDB-YCSB
./release-run-med.sh
python3 release-extract-med.py
cat RESULT.csv
```
"The expected results will appear as follows. If we are using the same node
(r6525), the performance numbers may show some variation, but the trends
remain (please see Appendix A.5 for details).

```
Workload,APPonly,OSonly,CrossP[+predict+opt],CrossP[+fetchall+opt]
ycsbwklda,74102,68327,79685....
ycsbwkldb,316638,340164,583153....
.....
```

##### Running RocksDB + DB_bench

Next, we will run RocksDB with a widely used KV benchmark DB_bench.

```
cd $BASE/appbench/apps/rocksdb
./compile.sh
./gendata-run-med.sh
./release-run-med.sh
```
The above script will first warm up and generate the database with a raw uncompressed size of 100GB and run the experiment on 4 million key-value pairs.   

Results will be generated in the following folder for 4M keys for different access patterns.

To extract and see the results 
```
python3 release-extract-med.py
cat RESULT.csv
```

Note: We observe that OSonly performance may vary on different machines with varying SSD
storage due to its reliance on OS prefetching, which can be unpredictable and occasionally 
improve performance. This highlights the need for a Cross-layered approach.

(2) Next, we will understanding Scalability for RocksDB + DB_bench
```
cd $BASE/appbench/apps/rocksdb
./release-scale-run-med.sh
python3 release-scale-extract-med.py
cat SCALE-RESULT.csv
```


##### Running MMAP 

Next, run the microbenchmark for MMAP, which will create a large data file (64GB) and issue 32 threads to access it concurrently.

```
cd $BASE/appbench/apps/simple_bench/mmap_exp/
./compile.sh
./release-run-med.sh
python3 release-extract-med.py
cat RESULT.csv
```

##### Running shared file access

Next, run the microbenchmark for shared file access, which will create 4 writer threads and vary reader threads from 1 to 16.

```
cd $BASE/appbench/apps/simple_bench/scalability/
./compile.sh
./release-run-med.sh
python3 release-extract-med.py
cat RESULT.csv
```

#### Long Running (> 1 hour)
We now discuss the results for long-running workloads, which can vary from tens
of minutes to a few hours, dependent on the machine configuration.

##### Running Snappy (Memory Budget)

The snappy experiment runs a benchmark that concurrently compresses different
folders across threads. We generate an input of around 300GB-350GB of data. The
scripts also reduce the available memory for the application to study the
effectiveness of CrossPrefetch under reducing memory capacity.

```
cd $BASE/appbench/apps/snappy-c
./compile.sh
# The value indicates an input to generate the dataset
./gendata-run-med.sh 1
./release-run-med.sh 
python3 release-extract-med.py
cat RESULT.csv
```

#### Running Remote Storage Experiments
For remote storage experiments, we will use `m510` with remote NVMe support.
These nodes are easily available and quick to launch!  We have already created
a publicly available Cloudlab profile where one could launch two `m510` NVMe
nodes with NVMe-oF setup across these nodes. In addition, we also provide an easy-to-use script to set up the NVMe-oF.

Please follow the following steps:

**1. Instantiating the nodes**

(1) First, create two CloudLab UTAH `m510` nodes by using the profile `2-NVMe-Nodes`

(2) Next, clone our provided script on both nodes to set up the NVMe-oF

```
cd crossprefetch-asplos24-artifacts
cd scripts/remote-nvme-setup/
```

(3)  Next, we need to set up the storage and client node separately. 

On Storage Node:

You can pick whatever node you want as a storage node, but just make sure the machine IP matches with the `IP_ADDR` in the `storage_setup.sh` script
```
# First, format the NVMe partition that you want the client to use.
sudo mkfs.ext4 /dev/nvme0n1p4

# Then replace ""/dev/nvme0n1p4" in storage_setup.sh with the target block device.
# Also make sure IP_ADDR in storage_setup.sh to be the addr of the TARGET machine, and run the script.
sudo ./storage_setup.sh
```

On Client Node:

The remaining node will be the client node. For the client node, same as the local experiment, we need to compile and install the modified kenrel, set the environmental variable, and install the user-level library. Please refer to above local experiment instructions

Before running the script, ensure the `IP_ADDR` in the `client_setup.sh` uses the IP address of the **Storage Node**.

```
# Make sure ADDR with the IP address of the storage machine IP.
sudo ./client_setup.sh
```
After that, you can run `lsblk` to check that the `/mnt/remote` is mounted on the remote disk `/dev/nvme1n1` 

**2. Running experiments**

For remote storage execution, we need to run the following scripts on the client node.

```
cd $BASE/appbench/apps/rocksdb
./compile.sh
./gendata-run-remote-med.sh
./release-run-remote-med.sh
python3 release-extract-remote-med.py
#Display the results
cat REMOTE-RESULT.csv
```

