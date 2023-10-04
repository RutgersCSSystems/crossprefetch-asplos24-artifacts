#!/usr/bin/env python

# Need to convert to python3 at some point by removing commands

import sys, os
import xml.etree.ElementTree as ET
import commands
import shutil
import time

def print_usage():
    print("Usage: experiment.py <experiment xml file>")
    pass

def check_env():
    req_env_vars = ["VTUNE_PATH", "RESULTS_PATH"]

    for env_var in req_env_vars:
        if env_var in os.environ:
            print("Found: " + env_var + " = " + os.environ[env_var])
        else:
            print(env_var + " is not defined. Can not continue")
            exit(1)

def parse_XML(file_path):
    tree = ET.parse(file_path)
    root = tree.getroot()

    # Create configuration object
    configuration = {}
    
    # Get test name
    configuration["name"] = root.find("name").text

    # Get test folder
    configuration["folder"] = root.find("folder").text

    # Get test runs and their keys
    configuration["runs"] = []
    for run in root.findall("run"):
        run_info = {}
        for element in run:
            if element.text != None:
                run_info[element.tag] = element.text
            else:
                run_info[element.tag] = ""
        configuration["runs"].append(run_info)

    # Return configuration object
    return configuration

def clear_pagecache(debug):
    # Flush any caches
    debug("Flushing Caches")
    os.system('sudo sh -c "sync; echo 3 > /proc/sys/vm/drop_caches"')    
    os.system('sudo sh -c "sync; echo 3 > /proc/sys/vm/drop_caches"')
    os.system('sudo sh -c "sync; echo 3 > /proc/sys/vm/drop_caches"')
    os.system('sleep 2')

def execute_run(test_folder, run, debugger):

    def debug(string):
        debugger("[" + run["name"] + "] " + string)

    #print(str(run)) # print whole config object

    #debug("Running Run: " + run["name"])
    debug("Description: " + run["description"])

    run_folder = os.path.join(test_folder, run["folder"])
    debug("Run folder is located: " + run_folder)

    # check if run folder exists
    if not os.path.isdir(run_folder):
        debug("Run folder " + run_folder + " not found. Creating...")
        os.mkdir(run_folder)

    # 1. Run with /usr/bin/time -v
    if "time" in analysis:
        clear_pagecache(debug)
        time_folder = os.path.join(run_folder, "time")
        #debug("Removing any existing result")
        if os.path.isdir(time_folder):
            #debug("Trying to remove result")
            shutil.rmtree(time_folder)
            #os.system("rm -rf " + time_folder)
        #if not os.path.isdir(time_folder):
        #    debug("Sucessfully removed result")
        #else:
        #    debug("Failed to remove result")
        os.mkdir(time_folder)
        debug("/usr/bin/time output folder: " + time_folder)
        output_file = os.path.join(time_folder, run["folder"] + "_output.txt")
        command = "/usr/bin/time -v " + run["command"] + " 2>&1 | tee -a " + output_file
        debug("Running command: " + command)
        start_time = time.time()
        commands.getstatusoutput(command)
        debug("Ran in %s seconds" % (time.time() - start_time))

    # 2. Run with strace -c
    if "strace" in analysis:
        clear_pagecache(debug)
        strace_folder = os.path.join(run_folder, "strace")
        #debug("Removing any existing result")
        if os.path.isdir(strace_folder):
            #debug("Trying to remove result")
            shutil.rmtree(strace_folder)
            #os.system("rm -rf " + time_folder)
        #if not os.path.isdir(time_folder):
        #    debug("Sucessfully removed result")
        #else:
        #    debug("Failed to remove result")
        os.mkdir(strace_folder)
        debug("strace output folder: " + strace_folder)
        output_file = os.path.join(strace_folder, run["folder"] + "_strace_output.txt")
        command = "/usr/bin/time -v strace -c " + run["command"] + " 2>&1 | tee -a " + output_file
        debug("Running command: " + command)
        start_time = time.time()
        commands.getstatusoutput(command)
        debug("Ran in %s seconds" % (time.time() - start_time))


    # 3. Run with user level hotspots
    if "vtune-usr" in analysis:
        clear_pagecache(debug)
        vtune_usr_hotspots_folder = os.path.join(run_folder, run["folder"] + "_vtune_usr_hotspots")
        #debug("Removing any existing result")
        if os.path.isdir(vtune_usr_hotspots_folder):
            #debug("Trying to remove result")
            shutil.rmtree(vtune_usr_hotspots_folder)
            #os.system("rm -rf " + vtune_usr_hotspots_folder)
        #if not os.path.isdir(vtune_usr_hotspots_folder):
        #    debug("Sucessfully removed result")
        #else:
        #    debug("Failed to remove result")
        debug("Vtune Usermode Hotspots folder: " + vtune_usr_hotspots_folder)
        command = "$VTUNE_PATH/bin64/amplxe-cl -collect hotspots -knob enable-stack-collection=true "
        command += "-r " + vtune_usr_hotspots_folder + " "
        command += "-app-working-dir " + run_folder + " "
        command += "-- " + run["command"]
        debug("Running Vtune Usermode Hotspot Analysis")
        debug("Running Command: " + command)
        start_time = time.time()
        commands.getstatusoutput(command)    
        hotspots_output_path = os.path.join(vtune_usr_hotspots_folder, run["folder"] + "_vtune_usr_hotspots.csv")
        command = "$VTUNE_PATH/bin64/amplxe-cl -report hotspots -format=csv "
        command += "-result-dir " + vtune_usr_hotspots_folder + " "
        command += "-report-output " + hotspots_output_path
        debug("Exporting hotspots to " + hotspots_output_path)
        debug("Running Command: " + command)
        commands.getstatusoutput(command)
        debug("Ran in %s seconds" % (time.time() - start_time))

    # 4. Run with hw w/o stacks
    if "vtune-hw" in analysis:
        clear_pagecache(debug)
        vtune_hw_hotspots_folder = os.path.join(run_folder, run["folder"] + "_vtune_hw_hotspots")
        #debug("Removing any exising result")
        if os.path.isdir(vtune_hw_hotspots_folder):
            #debug("Trying to remove result")
            shutil.rmtree(vtune_hw_hotspots_folder)
            #os.system("rm -rf " + vtune_hw_hotspots_folder)
        #if not os.path.isdir(vtune_hw_hotspots_folder):
        #    debug("Sucessfully removed result")
        #else:
        #    debug("Failed to remove result")
        debug("Vtune HW Hotspots folder: " + vtune_hw_hotspots_folder)
        command = "$VTUNE_PATH/bin64/amplxe-cl -collect hotspots -knob sampling-mode=hw "
        command += "-r " + vtune_hw_hotspots_folder + " "
        command += "-app-working-dir " + run_folder + " "
        command += "-- " + run["command"]
        debug("Running Vtune HW Hotspot Analysis")
        debug("Running Command: " + command)
        start_time = time.time()
        commands.getstatusoutput(command)
        hotspots_output_path = os.path.join(vtune_hw_hotspots_folder, run["folder"] + "_vtune_hw_hotspots.csv")
        command = "$VTUNE_PATH/bin64/amplxe-cl -report hotspots -format=csv "
        command += "-result-dir " + vtune_hw_hotspots_folder + " "
        command += "-report-output " + hotspots_output_path
        debug("Exporting hotspots to " + hotspots_output_path)
        debug("Running Command: " + command)
        commands.getstatusoutput(command)
        debug("Ran in %s seconds" % (time.time() - start_time))

    # 5. Run vtune hw w/ stacks
    if "vtune-hw-stacks" in analysis:
        clear_pagecache(debug)
        vtune_hw_hotspots_stacks_folder = os.path.join(run_folder, run["folder"] + "_vtune_hw_hotspots_stacks")
        #debug("Removing any existing result")
        if os.path.isdir(vtune_hw_hotspots_stacks_folder):
            #debug("Trying to remove result")
            shutil.rmtree(vtune_hw_hotspots_stacks_folder)
            #os.system("rm -rf " + vtune_hw_hotspots_stacks_folder)
        #if not os.path.isdir(vtune_hw_hotspots_stacks_folder):
        #    debug("Sucessfully removed result")
        #else:
        #    debug("Failed to remove result")
        debug("Vtune HW Hotspots with stacks folder: " + vtune_hw_hotspots_stacks_folder)    
        command = "$VTUNE_PATH/bin64/amplxe-cl -collect hotspots -knob sampling-mode=hw -knob enable-stack-collection=true "
        command += "-r " + vtune_hw_hotspots_stacks_folder + " "
        command += "-app-working-dir " + run_folder + " "
        command += "-- " + run["command"]
        debug("Running Vtune HW Hotspot Analysis with stacks")
        debug("Running Command: " + command)
        start_time = time.time()
        commands.getstatusoutput(command)
        hotspots_output_path = os.path.join(vtune_hw_hotspots_stacks_folder, run["folder"] + "_vtune_hw_hotspots_stacks.csv")
        command = "$VTUNE_PATH/bin64/amplxe-cl -report hotspots -format=csv "
        command += "-result-dir " + vtune_hw_hotspots_stacks_folder + " "
        command += "-report-output " + hotspots_output_path
        debug("Exporting hotspots to " + hotspots_output_path)
        debug("Running Command: " + command)
        commands.getstatusoutput(command)
        debug("Ran in %s seconds" % (time.time() - start_time))

    # 6. Run with perf
    if "perf" in analysis:
        clear_pagecache(debug)
        perf_folder = os.path.join(run_folder, "perf")
        #debug("Removing any existing result")
        if os.path.isdir(perf_folder):
            #debug("Trying to remove result")
            shutil.rmtree(perf_folder)
            #os.system("rm -rf " + time_folder)
        #if not os.path.isdir(time_folder):
        #    debug("Sucessfully removed result")
        #else:
        #    debug("Failed to remove result")
        os.mkdir(perf_folder)
        debug("perf output folder: " + perf_folder)
        output_file = os.path.join(perf_folder, run["folder"] + "_perf_output.data")
        command = "perf record -e cpu-clock --call-graph dwarf -o " + output_file + " " + run["command"]
        debug("Running command: " + command)
        start_time = time.time()
        commands.getstatusoutput(command)
        debug("Ran in %s seconds" % (time.time() - start_time))


def debug(string):
    res_string = "[" + experiment_name + "] " + string
    print(res_string.replace("] [", "]["))

# Check input
if len(sys.argv) < 2:
    print("Incorrect number of arguments")
    print_usage()
    sys.exit(1)

# Check for specific analysis
#analysis = ["time", "strace", "vtune-usr", "vtune-hw", "vtune-hw-stacks"]
analysis = ["vtune-hw"]
if len(sys.argv) > 2:
    analysis = []
    for x in range(2, len(sys.argv)):
        analysis.append(sys.argv[x])

#print(str(analysis))

test_file = sys.argv[1]
print("Using the following test file: " +  test_file)

# Check if test file is valid
if not os.path.isfile(test_file):
    print("Test file not found")
    exit(1)
elif not test_file.endswith(".xml"):
    print("Test file not an xml file")
    exit(1)

# Check required environment variables
check_env()
config = parse_XML(test_file)

# Get main start time
main_start_time = time.time()

# set experiment name 
experiment_name = config["name"]

# check for results folder
if not os.path.isdir(os.environ["RESULTS_PATH"]):
    print("Result folder not found. Creating it...")
    os.mkdir(os.environ["RESULTS_PATH"])

# check for test folder
test_folder = os.path.join(os.path.abspath(os.environ["RESULTS_PATH"]), config["folder"])
debug("Test folder is located: " + test_folder)

if not os.path.isdir(test_folder):
    debug("Test folder " + test_folder + " not found. Creating...")
    os.mkdir(test_folder)

for run in config["runs"]:
    debug("Going to execute run \"" + run["name"] + "\"")
    execute_run(test_folder, run, debug)

debug("Ran in %s seconds" % (time.time() - main_start_time))
