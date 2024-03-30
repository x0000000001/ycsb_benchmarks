#!/bin/bash

# TODO play with threads count

tests_folder="./tests"
cluster_script="./cluster_manage.sh"
execs_count=10

folder_for_test() {
	bdd=$1
	workload=$2
	nodes=$3
	threads=$4
	folder="$tests_folder/$workload/$nodes/$threads/$bdd"
	mkdir -p $folder
	echo $folder
}

test() {
	bdd=$1
	workload=$2
	nodes=$3
	threads=$4
	path=$(folder_for_test $bdd $workload $nodes $threads)

	$cluster_script $bdd stop
	$cluster_script $bdd start $nodes
	if [[ $bdd = "mongo" ]]; then
		# echo "PLEASE GO TO \"127.0.0.1:27017\" AND PRESS ENTER WHEN PAGE RESPONDS."
		# read
		sleep 15
	else
		sleep 5
	fi

	$cluster_script $bdd load $workload

	for i in $(seq 1 $execs_count); do
		echo "##########################################"
		echo "TEST $i/$execs_count"
		echo "##########################################"
		iteration_path="$path/$i"
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

all() {
	bdd=$1

	declare -a workload_choices=("100_0" "50_50" "10_90")
	declare -a nodes_choices=(3 5)
	declare -a threads_choices=(1 2 3 4 5)

	for workload in "${workload_choices[@]}"; do
		for nodes in "${nodes_choices[@]}"; do
			for threads in "${threads_choices[@]}"; do
				echo "BDD=${bdd}, WORKLOAD=${workload}, NODES=${nodes}, THREADS=${threads}"
				test $bdd $workload $nodes $threads
			done
		done
	done
}

main() {
	bdd=$1
	workload=$2
	nodes=$3
	threads=$4

	if [[ $workload = "all" ]]; then
		all $bdd
		exit 0
	fi

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
