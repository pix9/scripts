#!/bin/bash
# Name :- Pushkar Madan
# Email:- pushkarmadan@yahoo.com
# Date :- 26th December 2016
# Purpose :- To demonstarate get opts and shift command in script.

ARG=""

_help(){
echo -e "Usage :- $0 -h (for Help)\n\t $0 -p \"<name to print>\"" 2>&1; exit 1;
}

check_args(){
if [ -z "${ARG}" ]; then _help; fi
}

while getopts ":h:p:" o ; do
	case ${o} in
		h)
			ARG=${OPTARG}
			_help
		;;

		p)
			ARG=${OPTARG}
		;;

		*)
			_help
		;;
	esac
done
shift $((OPTIND-1))			

check_args

echo ${ARG}
