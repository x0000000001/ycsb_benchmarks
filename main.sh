#!/bin/bash

# TODO play with threads count

tests_folder="./tests"
cluster_script="./cluster_manage.sh"
execs_count=10

folder_for_test() {
	workload=$1
	folder="$tests_folder/$workload"
	mkdir -p $folder
	echo $folder
}

test_file() {
	bdd=$1
	workload=$2
	nodes=$3
	folder=$(folder_for_test $workload)
	echo "$folder/${bdd}_${nodes}nodes_"
}

# FIXME mongo doesn't load right
# when called fom here

test() {
	bdd=$1
	workload=$2
	nodes=$3
	path=$(test_file $bdd $workload $nodes)

	$cluster_script $bdd stop
	$cluster_script $bdd start $nodes
	$cluster_script $bdd load $workload

	for i in $(seq 1 $execs_count); do
		echo "##########################################"
		echo "TEST $i/$execs_count"
		echo "##########################################"
		iteration_path="$path$i"
		$cluster_script $bdd run $workload $iteration_path
	done

	$cluster_script $bdd stop
}

main() {
	bdd=$1
	workload=$2
	nodes=$3

	if [[ "$bdd" = "" ]]; then
		echo "please specify a database"
		exit 1
	fi

	if [[ "$workload" = "" ]]; then
		echo "please specify a workload"
		exit 1
	fi

	if [[ "$nodes" = "" ]]; then
		echo "please specify a number of nodes"
		exit 1
	fi

	case $bdd in
	"mongo" | "redis")
		test $bdd $workload $nodes
		;;
	*)
		echo "unknown database : $bdd"
		exit 1
		;;
	esac

	workload=$2
}

main "$@"
