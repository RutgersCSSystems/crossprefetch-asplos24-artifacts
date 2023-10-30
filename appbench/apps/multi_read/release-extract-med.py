import os
import csv

# Define the arrays
thread_arr = ["16"]
workload_arr = ["pvt_seq", "pvt_rand", "shared_seq", "shared_rand"]
config_arr = ["Vanilla", "OSonly", "CII", "CIP", "CIPI_PERF"]
config_out_arr = ["APPonly", "OSonly", "CrossP[+fetchall+opt]", "CrossP[+predict]", "CrossP[+predict+opt]"]
readsize_arr = ["128"]

# Base directory for output files
output_dir = os.environ.get("OUTPUTDIR", "")
base_dir_template = f"{output_dir}/simplebench/{{workload}}/"

# Output CSV file
output_file = "RESULT.csv"

# Function to extract the value before "MB/s" from a line and round to the nearest integer
def extract_and_round_ops_per_sec(line):
    parts = line.split()
    ops_index = parts.index("MB/sec")
    ops_sec_value = float(parts[ops_index - 1])
    return round(ops_sec_value)

# Main function to iterate through workloads and extract MB/s
def main():
    with open(output_file, mode='w', newline='') as csv_file:
        csv_writer = csv.writer(csv_file)

        for access_pattern in workload_arr:
            SPACE =[f"-----------------------"]
            csv_writer.writerow(SPACE)
            header_row = [f"Table for {access_pattern}"]
            csv_writer.writerow(header_row)
            csv_writer.writerow(SPACE)

            #header_row = ["rsize"] + config_out_arr
            header_row = config_out_arr
            csv_writer.writerow(header_row)

            #for readsize in readsize_arr:
            for workload in workload_arr:
                if workload != access_pattern:
                    continue  # Skip if not the desired access pattern

                base_dir = base_dir_template.format(workload=workload)
                #workload_data = [readsize]
                workload_data = []

                for config in config_arr:
                    file_path = os.path.join(base_dir, thread_arr[0], f"{config}.out")
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

