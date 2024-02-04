import os
import csv

# Define the arrays
thread_arr = ["32"]
workload_arr=["multireadrandom", "readreverse", "readseq", "readwhilescanning"]
workload_arr=["multireadrandom"]
config_arr = ["Vanilla", "OSonly", "CII", "CIPI_PERF_NOOPT", "CIPI_PERF"]
config_out_arr = ["APPonly", "OSonly","CrossP[+fetchall+opt]",  "CrossP[+predict]",  "CrossP[+predict+opt]"]

# Base directory for output files
output_dir = os.environ.get("OUTPUTDIR", "")
print(output_dir)
base_dir = output_dir + "/ROCKSDB/40M-KEYS/"
print(base_dir)

# Output CSV file
output_file = "RESULT.csv"

# Function to extract the value before "MB/s" from a line and round to the nearest integer
def extract_and_round_ops_per_sec(line):
    parts = line.split()
    print(line)
    ops_index = parts.index("MB/s")
    ops_sec_value = float(parts[ops_index - 1])
    return round(ops_sec_value)

# Main function to iterate through workloads and extract MB/s
def main():
    with open(output_file, mode='w', newline='') as csv_file:
        csv_writer = csv.writer(csv_file)
        
        # Write the header row with column names from config_arr
        header_row = ["Workload"] + config_out_arr
        csv_writer.writerow(header_row)

        for workload in workload_arr:
            workload_data = [workload]
            
            for config in config_arr:
                file_path = os.path.join(base_dir, workload, thread_arr[0], f"{config}.out")
                if os.path.exists(file_path):
                    with open(file_path, 'r') as file:
                        lines = file.readlines()
                        ops_sec_found = False
                        for line in lines:
                            if "MB/s" in line:
                                ops_sec_value = extract_and_round_ops_per_sec(line)
                                workload_data.append(ops_sec_value)
                                ops_sec_found = True
                                break
                        if not ops_sec_found:
                            workload_data.append("N/A")
                else:
                    print(f"File not found: {file_path}")

            csv_writer.writerow(workload_data)

if __name__ == "__main__":
    main()

