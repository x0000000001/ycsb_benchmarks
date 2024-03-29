#!/bin/bash

# TODO play with threads count

tests_folder="./tests"
cluster_script="./cluster_manage.sh"
execs_count=10

folder_for_test() {
	workload=$1
	threads=$2
	folder="$tests_folder/workload_$workload/threads_$threads"
	mkdir -p $folder
	echo $folder
}

test_file() {
	bdd=$1
	workload=$2
	nodes=$3
	threads=$4
	folder=$(folder_for_test $workload $threads)
	echo "$folder/${bdd}_${nodes}nodes_"
}

# FIXME mongo doesn't load right
# when called fom here

test() {
	bdd=$1
	workload=$2
	nodes=$3
	threads=$4
	path=$(test_file $bdd $workload $nodes $threads)

	$cluster_script $bdd stop
	$cluster_script $bdd start $nodes
	if [[ $bdd = "mongo" ]]; then
		echo "PLEASE GO TO \"127.0.0.1:27017\" AND PRESS ENTER WHEN PAGE RESPONDS."
		read
	fi

	$cluster_script $bdd load $workload

	for i in $(seq 1 $execs_count); do
		echo "##########################################"
		echo "TEST $i/$execs_count"
		echo "##########################################"
		iteration_path="$path$i"
		$cluster_script $bdd run $workload $threads $iteration_path
	done

	$cluster_script $bdd stop
}

help() {
	echo "Usage: ./cluster_management.sh <database> <workload> <nodes> <threads>"
	echo
	echo "Description:"
	echo "  This script is used to automate the setup, testing, and teardown of database clusters."
	echo
	echo "Arguments:"
	echo "  <database>      Specify the database to manage: 'mongo' or 'redis'."
	echo "  <workload>      Specify the workload file to use for testing."
	echo "  <nodes>         Specify the number of nodes in the cluster to start."
	echo "  <threads>       Specify the number of client threads YCSB should use."
	echo
	echo "Options:"
	echo "  -h, --help      Show this help message and exit."
	echo
	echo "Examples:"
	echo "  ./cluster_management.sh redis workload_file 3 1"
	echo "  ./cluster_management.sh mongo workload_file 5 3"
	echo
	echo "Note:"
	echo "  - Ensure Docker is installed and running."
	echo "  - Workload files should be located in the 'workloads' directory."
}

main() {
	bdd=$1
	workload=$2
	nodes=$3
	threads=$4

	if [[ "$bdd" = "" ]] || [[ "$workload" = "" ]] || [[ "$nodes" = "" ]] || [[ "$threads" = "" ]]; then
		help
		exit 0
	fi

	case $bdd in
	"mongo" | "redis")
		test $bdd $workload $nodes $threads
		;;
	*)
		echo "unknown database : $bdd"
		help
		exit 0
		;;
	esac

	workload=$2
}

if [[ "$1" == "-h" || "$1" == "--help" ]]; then
	help
	exit 0
fi

main "$@"
