set -o errexit
set -o nounset
set -o pipefail
TEST_PATH=$(pwd)
script_name=$(basename "$0")
tests_passing=""
TEST_IMAGES=($(jq -r .file.image_lists[] test_config.json | tr " " "\n"))

source $TEST_PATH/lib.sh
usage() {
	exit_code="$1"
	cat <<EOF
Overview:
    Tests for confidential containers
    ${script_name} <command>
Commands:
	-b:	Multiple pod spec and container image tests
	-e:	Encrypted image tests
	-s:	Signed image tests
	-t:	Trusted storage for container image tests
	-o:	Install && Uninstall Operator tests
	-h:	help
EOF
}
parse_args() {
	while getopts "bestohd:" opt; do
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
				tests_passing+="Test signed image"
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
		o)
			if [ "$tests_passing" == "" ]; then
				# echo "Test trust storage"
				tests_passing+="Test install operator|Test unstall operator"
			else
				# echo "|Test trust storage"
				tests_passing+="|Test uninstall operator|Test unstall operator"
			fi
			;;
		h) usage 0 ;;
		# p) usage 0 ;;
		*)
			echo "Invalid option: -$OPTARG" >&2
			usage 1
			;;
		esac
	done
}

run_non_tee_tests() {

	echo $tests_passing
	# exit 0

	bats -f "$tests_passing" \
		"k8s_non_tee_cc.bats"

}
modify_config_json() {
	old_value=$(awk -F"\"" '/podConfigPath/{print $4}' test_config.json)
	sed -e "s@${old_value%/*}@$TEST_PATH@" -i test_config.json

}
print_image() {
	IMAGES=($1)
	for IMAGE in "${IMAGES[@]}"; do
		echo "    $IMAGE $(docker image ls | grep $IMAGE | head -1 | awk '{print $7}')"
	done
}
main() {
	parse_args $@
	./serverinfo-stdout.sh
	echo -e "\n\n"
	echo "--------Operator Version--------"
	OPERATOR_VERSION=$(jq -r .file.operator_version test_config.json)
	echo "Operator Version: $OPERATOR_VERSION"

	echo -e "\n--------Test Images--------"

	EXAMPLE_IMAGE_LISTS=$(jq -r .file.comments_image_lists[] test_config.json)
	echo -e "unsigned unencrpted images: "
	print_image "${EXAMPLE_IMAGE_LISTS[@]}"
	echo -e "trust storage images: "
	print_image "${EXAMPLE_IMAGE_LISTS[@]}"
	echo -e "signed images: "
	print_image "${EXAMPLE_IMAGE_LISTS[@]}"
	echo -e "\n\n"
	exit 0
	echo "install Kubernetes"
	./setup/setup.sh

	modify_config_json
	run_non_tee_tests

}

main "$@"
