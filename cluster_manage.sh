#!/bin/bash

python2path="./Python-2.7.2/python"
ycsb_path="./ycsb"

redis_cluster_config="./cluster-config-template.conf"
redis_port=6379
redis_network_name="redisCluster"

mongo_network_name="mongocluster"
mongo_replica_name="mongoreplicaset"

check_workload() {
	path0="./workloads/workload$1"

	if [[ -f $path0 ]]; then
		echo $path0
		return
	fi

	path1="$ycsb_path/workloads/workload$1"

	if [[ -f $path1 ]]; then
		echo $path1
		return
	fi

	echo "Unknown workload : $workload"
	exit 1
}

# REDIS

redis_start() {
	echo "CREATING DOCKER NETWORK"
	sudo docker network create $redis_network_name

	echo "CREATING CONTAINERS"
	containers_count=$1
	ip_addresses=""

	for i in $(seq 1 $(($containers_count * 3))); do
		name="redis-$i"
		port=$(($redis_port + i))

		# --net $redis_network_name \
		sudo docker run -d -v $PWD/cluster-config.conf:/usr/local/etc/redis/redis.conf \
			--name $name \
			-p $port:$redis_port --net $redis_network_name \
			redis redis-server /usr/local/etc/redis/redis.conf

		ip_addresses="$ip_addresses $(sudo docker inspect -f '{{range.NetworkSettings.Networks}}{{.IPAddress}}{{end}}' $name):$redis_port"
	done

	echo "yes" | sudo docker exec -i redis-1 redis-cli --cluster create $ip_addresses --cluster-replicas $(($containers_count - 1))
}

redis_stop() {
	echo "STOPPING CONTAINERS" >/dev/tty
	sudo docker ps -a --format "{{.Names}}" | awk '/redis/' | xargs -r sudo docker stop
	sudo docker ps -a --format "{{.Names}}" | awk '/redis/' | xargs -r sudo docker rm
	echo "REMOVING DOCKER NETWORK" >/dev/tty
	sudo docker network rm $redis_network_name
}

redis_load_workload() {
	workload=$(check_workload $1)
	$python2path "$ycsb_path/bin/ycsb" load redis -s -P $workload -p "redis.host=127.0.0.1" -p "redis.port=$(($redis_port + 1))" -p "redis.cluster=true"
}

redis_run_workload() {
	workload=$(check_workload $1)
	redirect=$2

	# this is STUPID
	# but for whatever reason, a variable
	# with the ">" character will throw a
	# YCSB error
	if [[ "$redirect" != "" ]]; then
		$python2path "$ycsb_path/bin/ycsb" run redis -s -P $workload -p "redis.host=127.0.0.1" -p "redis.port=$(($redis_port + 1))" -p "redis.cluster=true" >$redirect
	else
		$python2path "$ycsb_path/bin/ycsb" run redis -s -P $workload -p "redis.host=127.0.0.1" -p "redis.port=$(($redis_port + 1))" -p "redis.cluster=true"
	fi
}

# MONGODB

mongo_get_connection_string() {
	sudo docker exec -it mongo1 mongosh --eval "db.getMongo()" | tail -n 1
}

mongo_start() {
	echo "CREATING DOCKER NETWORK"
	sudo docker network create $mongo_network_name

	echo "CREATING CONTAINERS"
	containers_count=$1
	members="["

	# containers creation
	for i in $(seq 1 $containers_count); do
		sudo docker run -d --rm -p $((27017 + $i - 1)):27017 --name mongo$i --network $mongo_network_name mongo:5 mongod --replSet $mongo_replica_name --bind_ip localhost,mongo$i

		if [[ $i -ne 1 ]]; then
			members="$members,"
		fi

		members="$members{_id: $((i - 1)), host: \"mongo$i\"}"
	done

	members="$members]"
	echo $members >/dev/tty

	sudo docker exec -it mongo1 mongosh --eval "rs.initiate({_id: \"$mongo_replica_name\",members: $members})"
}

mongo_stop() {
	echo "STOPPING CONTAINERS" >/dev/tty
	sudo docker ps -a --format "{{.Names}}" | awk '/mongo/' | xargs -r sudo docker stop
	echo "REMOVING DOCKER NETWORK" >/dev/tty
	sudo docker network rm $mongo_network_name
}

mongo_status() {
	sudo docker exec -it mongo1 mongosh --eval "rs.status()"
}

mongo_load_workload() {
	connection_string=$(mongo_get_connection_string)
	workload=$(check_workload $1)
	$python2path "$ycsb_path/bin/ycsb" load mongodb -s -P $workload -p mongodb.url=$connection_string
}

mongo_run_workload() {
	connection_string=$(mongo_get_connection_string)
	workload=$(check_workload $1)
	redirect=$2

	# this is STUPID
	# but for whatever reason, a variable
	# with the ">" character will throw a
	# YCSB error
	if [[ "$redirect" != "" ]]; then
		$python2path "$ycsb_path/bin/ycsb" run mongodb -s -P $workload -p mongodb.url=$connection_string >$redirect
	else
		$python2path "$ycsb_path/bin/ycsb" run mongodb -s -P $workload -p mongodb.url=$connection_string
	fi
}

# CLI

mongo_handler() {
	case $2 in
	"start")
		mongo_start $3
		;;
	"stop")
		mongo_stop
		;;
	"load")
		mongo_load_workload $3
		;;
	"run")
		mongo_run_workload $3 $4
		;;
	"status")
		mongo_status
		;;
	*)
		help
		;;
	esac
}

redis_handler() {
	case $2 in
	"start")
		redis_start $3
		;;
	"stop")
		redis_stop
		;;
	"load")
		redis_load_workload $3
		;;
	"run")
		redis_run_workload $3 $4
		;;
	*)
		help
		;;
	esac
}

help() {
	echo "Usage: ./cluster_manage.sh <database> <command> [options]"
	echo
	echo "Commands:"
	echo "  start <count>    Start the database cluster with the specified number of nodes."
	echo "  stop             Stop and remove the database cluster and associated Docker network."
	echo "  load <workload>  Load a workload into the database cluster."
	echo "  run <workload>   Run a workload on the database cluster."
	echo "  status           Check the status of the MongoDB replica set."
	echo
	echo "Databases:"
	echo "  redis            Manage Redis cluster."
	echo "  mongo            Manage MongoDB replica set."
	echo
	echo "Options:"
	echo "  <count>          Number of nodes to start in the cluster."
	echo "  <workload>       Workload file name to load or run (without 'workload' at the beginning)."
	echo
	echo "Example:"
	echo "  ./cluster_manage.sh redis start 3"
	echo "  ./cluster_manage.sh mongo load a"
	echo "  ./cluster_manage.sh mongo run a"
	echo "  ./cluster_manage.sh mongo stop"
	echo
	echo "Note:"
	echo "  - Ensure Docker is installed and daemon is running ('dockerd' in another console)."
	echo "  - Workload files should be located in the 'workloads' directory within YCSB."
	echo "  - Modify configuration variables within the script as needed."
}

case $1 in
"redis") redis_handler "$@" ;;
"mongo") mongo_handler "$@" ;;
*) help ;;
esac
