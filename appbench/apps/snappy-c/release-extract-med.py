import os
import csv

# Define the arrays
thread_arr = ["32"]
workload_arr = ["100"]
filesize_arr = ["140000"]
config_arr = ["Vanilla",  "OSonly", "CII", "CIPI_PERF"] 
config_out_arr = ["APPonly", "OSonly", "CrossP[+fetchall+opt]" "CrossP[+predict+opt]"]
membudget = ["10", "11", "12", "13", "14"]

# Base directory for output files
output_dir = os.environ.get("OUTPUTDIR", "")
output_base_dir = f"{output_dir}/snappy/"

# Output CSV file
output_file = "RESULT.csv"

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

            for filesize in filesize_arr:
                header_row = [f"Datasize", "MemRedFac"] + config_out_arr
                csv_writer.writerow(header_row)

                for workload in workload_arr:
                    # Calculate the datasize as the product of Workload and Filesize
                    datasize = int(workload) * int(filesize)

                    for budget in membudget:
                        row_data = [datasize, budget]

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

