import os
import csv

# Define the arrays
filesize_arr = ["140000"]
# Define the arrays
thread_arr = ["32"]
workload_arr=["multireadrandom"]
config_arr = ["Vanilla", "OSonly", "CII", "CPBI_PERF", "CIPI_PERF"]
config_out_arr = ["APPonly", "OSonly","CrossP[+fetchall+opt]",  "CrossP[+predict]",  "CrossP[+predict+opt]"]
membudget = ["4", "3", "2", "1"]
membudgetproxy = ["1:6", "1:4", "1:2", "1:1"]

# Base directory for output files
output_dir = os.environ.get("OUTPUTDIR", "")
print(output_dir)
output_base_dir = output_dir + "-TRIAL1/ROCKSDB/15M-KEYS/"
print(output_base_dir)


# Output CSV file
output_file = "MEM-RESULT.csv"

# Function to extract the value before "MB/s" from a line and round to the nearest integer
def extract_and_round_ops_per_sec(line):
    parts = line.split()
    ops_index = parts.index("MB/s")
    ops_sec_value = float(parts[ops_index - 1])
    return round(ops_sec_value)

# Main function to iterate through arrays and extract MB/s
def main():
    with open(output_file, mode='w', newline='') as csv_file:
        csv_writer = csv.writer(csv_file)

        for thread in thread_arr:
            # Write the header row for each thread value
            header_row = [f"Thread {thread}"]
            csv_writer.writerow(header_row)

            #for filesize in filesize_arr:
            header_row = [f"MemRedFac"] + config_out_arr
            csv_writer.writerow(header_row)

            for workload in workload_arr:

                for i in range(len(membudget)):
                    budget = membudget[i]
                    budget_proxy = membudgetproxy[i]
                    row_data = [budget_proxy]

                    for config in config_arr:
                        base_dir = f"{output_base_dir}MEMFRAC{budget}/"
                        file_path = os.path.join(base_dir, workload, thread, config + ".out")

                        if os.path.exists(file_path):
                            with open(file_path, 'r') as file:
                                lines = file.readlines()
                                ops_sec_found = False
                                for line in lines:
                                    if "MB/s" in line:
                                        ops_sec_value = extract_and_round_ops_per_sec(line)
                                        row_data.append(ops_sec_value)
                                        ops_sec_found = True
                                        break
                                if not ops_sec_found:
                                    row_data.append("N/A")
                        else:
                            row_data.append("N/A")

                    csv_writer.writerow(row_data)

                # Add an empty line between consecutive tables
                csv_writer.writerow([])

if __name__ == "__main__":
    main()

