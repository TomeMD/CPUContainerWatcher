import sys
import os
import time
import requests

# Check if correct number of arguments is passed
if len(sys.argv) != 4:
    print("Error: Missing some arguments")
    print(f"Usage: {sys.argv[0]} <CORES_LIST> <INFLUXDB_HOST> <INFLUXDB_BUCKET>")
    sys.exit(1)

CORES_LIST = sys.argv[1]
INFLUXDB_HOST = sys.argv[2]
INFLUXDB_BUCKET = sys.argv[3]
CORES_ARRAY = CORES_LIST.split(',')

PREV_USER = {}
PREV_SYSTEM = {}
PREV_IOWAIT = {}
PREV_TOTAL = {}

# Initialize previous values for each core
for core in CORES_ARRAY:
    PREV_USER[core] = 0
    PREV_SYSTEM[core] = 0
    PREV_IOWAIT[core] = 0
    PREV_TOTAL[core] = 0

def compute_core_utilization(core, proc_lines):
    cpu_times = proc_lines[f"cpu{core}"]
    total_time = sum(cpu_times)

    diff_user = cpu_times[1] - PREV_USER[core]
    diff_system = cpu_times[3] - PREV_SYSTEM[core]
    diff_iowait = cpu_times[5] - PREV_IOWAIT[core]
    diff_total = total_time - PREV_TOTAL[core]

    user_util_core = 100 * diff_user / diff_total if diff_total else 0
    system_util_core = 100 * diff_system / diff_total if diff_total else 0
    iowait_util_core = 100 * diff_iowait / diff_total if diff_total else 0

    # Update previous values
    PREV_USER[core] = cpu_times[1]
    PREV_SYSTEM[core] = cpu_times[3]
    PREV_IOWAIT[core] = cpu_times[5]
    PREV_TOTAL[core] = total_time

    return user_util_core, system_util_core, iowait_util_core

def read_cpu_temperature():
    total_temp = 0
    for file in os.listdir("/sys/class/thermal"):
        if "thermal_zone" in file:
            with open(os.path.join("/sys/class/thermal", file, "temp"), "r") as temp_file:
                temp = int(temp_file.read().strip())
                total_temp += temp
    return total_temp // 1000

# ADAPTAR PARA MONITORIZAR CONTENEDORES!!!!

while True:
    total_freq = 0
    total_temp = read_cpu_temperature()
    user_util = 0
    system_util = 0
    iowait_util = 0
    proc_lines = {}

    with open("/proc/stat", "r") as file:
        for line in file:
            parts = line.split()
            if parts[0].startswith("cpu"):
                proc_lines[parts[0]] = list(map(int, parts[1:]))

    for core in CORES_ARRAY:
        with open(f"/sys/devices/system/cpu/cpu{core}/cpufreq/scaling_cur_freq", "r") as f:
            freq_core = int(f.read().strip())

        u_util, s_util, io_util = compute_core_utilization(core, proc_lines)
        total_freq += freq_core
        user_util += u_util
        system_util += s_util
        iowait_util += io_util

    avg_freq = total_freq // len(CORES_ARRAY) // 1000

    # Send data to InfluxDB
    timestamp = int(time.time() * 1e9)
    data = f"cpu_metrics freq={avg_freq} user={user_util} system={system_util} iowait={iowait_util} temp={total_temp} {timestamp}"
    response = requests.post(
        f"http://{INFLUXDB_HOST}:8086/api/v2/write?org=MyOrg&bucket={INFLUXDB_BUCKET}",
        headers={"Authorization": "Token MyToken"},
        data=data
    )
    print(response.text)

    time.sleep(1)
