set -o errexit
set -o nounset
set -o pipefail

# SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
# GOPATH=$(go env | grep GOPATH | cut -d '=' -f2)
# RUNTIME_CLASS="kata-qemu"
tests_passing=""
source ./lib.sh
usage() {
	exit_code="$1"
	cat <<EOF
Overview:
    Tests for confidential containers
    ${script_name} <command>
Commands:
-b:          			Multiple pod spec and container image tests
-e:						Encrypted image tests
-s:						Signed image tests
-t:						Trusted storage for container image tests
-h:						123
EOF
}
parse_args() {
	while getopts "besth:" opt; do
		case $opt in
		# b) tests_passing +="Test unencrypted unsigned image" ;;
		# e) tests_passing+="|Test encrypted image" ;;
		# s) tests_passing+="|Test signed image" ;;
		# t) tests_passing+="|Test trust storage" ;;

		b)
			if [ "$tests_passing" == "" ]; then
				# echo "Test unencrypted unsigned image"
				tests_passing+="Test unencrypted unsigned image"
			else
				# echo "|Test unencrypted unsigned image"
				tests_passing+="|Test unencrypted unsigned image"
			fi
			# read_config
			# restore
			;;
		e)
			if [ "$tests_passing" == "" ]; then
				# echo "Test encrypted image"
				tests_passing+="Test encrypted image"
			else
				# echo "|Test encrypted image"
				tests_passing+="|Test encrypted image"
			fi
			;;
		s)
			if [ "$tests_passing" == "" ]; then
				# echo "Test signed image"
				tests_passing +="Test signed image"
			else
				# echo "|Test signed image"
				tests_passing+="|Test signed image"
			fi
			;;
		t)
			if [ "$tests_passing" == "" ]; then
				# echo "Test trust storage"
				tests_passing+="Test trust storage"
			else
				# echo "|Test trust storage"
				tests_passing+="|Test trust storage"
			fi
			;;

		# h) usage 0 ;;
		# p) usage 0 ;;
		*)
			echo "Invalid option: -$OPTARG" >&2
			usage 1
			;;
		esac
	done
}

# tests for CC without specific hardware support
run_non_tee_tests() {
	# local runtimeclass="$1"

	# tests_passing="Test unencrypted unsigned image"
	# tests_passing+="|Test encrypted image"
	# tests_passing+="|Test signed image"
	# tests_passing+="|Test trust storage"
	echo $tests_passing
	bats -f "$tests_passing" \
		"k8s_non_tee_cc.bats"

}
main() {

	parse_args $@
	run_non_tee_tests

}

main "$@"
