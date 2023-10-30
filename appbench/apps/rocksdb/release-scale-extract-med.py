import os
import csv

# Define the arrays
thread_arr = ["1", "4", "8", "16", "32"]
workload_arr=["multireadrandom"]
config_arr = ["Vanilla", "OSonly", "CII", "CIPI_PERF_NOOPT", "CIPI_PERF"]
config_out_arr = ["APPonly", "OSonly","CrossP[+fetchall+opt]",  "CrossP[+predict]",  "CrossP[+predict+opt]"]

# Base directory for output files
output_dir = os.environ.get("OUTPUTDIR", "")
print(output_dir)
base_dir = output_dir + "-TRIAL1/ROCKSDB/4M-KEYS/SCALE"
print(base_dir)

# Output CSV file
output_file = "SCALE-RESULT.csv"

# Function to extract the value before "MB/s" from a line and round to the nearest integer
def extract_and_round_ops_per_sec(line):
    parts = line.split()
    #print(line)
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

        for thread in thread_arr:
            thread_data = [thread]
            workload = workload_arr[0]
            
            for config in config_arr:
                file_path = os.path.join(base_dir, workload, thread, f"{config}.out")
                if os.path.exists(file_path):
                    with open(file_path, 'r') as file:
                        lines = file.readlines()
                        ops_sec_found = False
                        for line in lines:
                            if "MB/s" in line:
                                ops_sec_value = extract_and_round_ops_per_sec(line)
                                thread_data.append(ops_sec_value)
                                ops_sec_found = True
                                break
                        if not ops_sec_found:
                            thread_data.append("N/A")
                else:
                    print(f"File not found: {file_path}")

            csv_writer.writerow(thread_data)

if __name__ == "__main__":
    main()

