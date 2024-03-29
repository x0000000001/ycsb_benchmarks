#!/bin/bash

# Function to extract specific metric values from a test report
extract_metric() {
	metric_name="$1"
	report_file="$2"
	value=$(grep "$metric_name" "$report_file" | awk -F', ' '{print $3}')
	echo "$value"
}

# CSV header
echo "Workload,Threads,Database,Nodes,Test ID,RunTime(ms),Throughput(ops/sec),Read_Operations,Read_AverageLatency(us),Read_MinLatency(us),Read_MaxLatency(us),Read_95thPercentileLatency(us),Read_99thPercentileLatency(us),Update_Operations,Update_AverageLatency(us),Update_MinLatency(us),Update_MaxLatency(us),Update_95thPercentileLatency(us),Update_99thPercentileLatency(us)" >results.csv

# Iterate through test folders
for workload_folder in tests/*; do
	workload=$(basename "$workload_folder")
	for nodes_folder in "$workload_folder"/*; do
		nodes=$(basename "$nodes_folder")
		for threads_folder in "$nodes_folder"/*; do
			threads=$(basename "$threads_folder")
			for db_folder in "$threads_folder"/*; do
				db_name=$(basename "$db_folder")
				for test_file in "$db_folder"/*; do
					test_id=$(basename $test_file)
					runtime=$(extract_metric "RunTime(ms)" "$test_file")
					throughput=$(extract_metric "Throughput(ops/sec)" "$test_file")

					# Extract metrics for READ operation
					read_operations=$(extract_metric "\[READ\], Operations" $test_file)
					read_average=$(extract_metric "\[READ\], AverageLatency" $test_file)
					read_min=$(extract_metric "\[READ\], MinLatency" $test_file)
					read_max=$(extract_metric "\[READ\], MaxLatency" $test_file)
					read_95th=$(extract_metric "\[READ\], 95thPercentileLatency" $test_file)
					read_99th=$(extract_metric "\[READ\], 99thPercentileLatency" $test_file)

					# Extract metrics for UPDATE operation
					update_operations=$(extract_metric "\[UPDATE\], Operations" $test_file)
					update_average=$(extract_metric "\[UPDATE\], AverageLatency" $test_file)
					update_min=$(extract_metric "\[UPDATE\], MinLatency" $test_file)
					update_max=$(extract_metric "\[UPDATE\], MaxLatency" $test_file)
					update_95th=$(extract_metric "\[UPDATE\], 95thPercentileLatency" $test_file)
					update_99th=$(extract_metric "\[UPDATE\], 99thPercentileLatency" $test_file)

					echo "$workload,$threads,$db_name,$nodes,$test_id,$runtime,$throughput,$read_operations,$read_average,$read_min,$read_max,$read_95th,$read_99th,$update_operations,$update_average,$update_min,$update_max,$update_95th,$update_99th" >>results.csv
				done
			done
		done
	done
done

echo "Results saved to results.csv"
