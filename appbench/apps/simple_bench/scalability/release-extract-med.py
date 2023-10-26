import os
import csv

# Define the arrays
thread_arr = ["1","4","8","16"]
#workload_arr = ["read_shared_mmap_rand", "read_shared_mmap_seq"]
#config_arr = ["Vanilla", "OSonly", "CIPI", "CIPI_interval"]
config_arr = ["Vanilla", "OSonly", "CIPI_PERF", "CIPI_interval"]
config_out_arr = ["APPonly", "OSonly", "CrossP[+predict+opt]", "CrossP[+fetchall+opt]"]

# Base directory for output files
output_dir = os.environ.get("OUTPUTDIR", "")
base_dir_template = f"./results/concurrency/4/{{thread}}/"

# Output CSV file
output_file = "RESULT.csv"

# Function to extract the value before "MB/s" from a line and round to the nearest integer
def extract_and_round_ops_per_sec(line):
    parts = line.split()
    ops_index = parts.index("sec")
    ops_sec_value = float(parts[ops_index - 1])
    return round(ops_sec_value)

# Main function to iterate through workloads and extract MB/s
def main():
    with open(output_file, mode='w', newline='') as csv_file:
        csv_writer = csv.writer(csv_file)

        SPACE =[f"-----------------------"]
        csv_writer.writerow(SPACE)
        header_row = [f"Table for shared access"]
        csv_writer.writerow(header_row)
        csv_writer.writerow(SPACE)

        header_row = ["threads"] + config_out_arr
        csv_writer.writerow(header_row)

        for thd in thread_arr :

            base_dir = base_dir_template.format(thread=thd)
            workload_data = []

            for config in config_arr:
                file_path = os.path.join(base_dir, f"{config}.out")
                print(file_path)
                if os.path.exists(file_path):
                    with open(file_path, 'r') as file:
                        lines = file.readlines()
                        ops_sec_found = False
                        for line in lines:
                            if "writer" in line:
                                print(line)
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

