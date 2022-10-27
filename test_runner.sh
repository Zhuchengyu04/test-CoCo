set -o errexit
set -o nounset
set -o pipefail
TEST_PATH=$(pwd)
script_name=$(basename "$0")
tests_passing=""

source $TEST_PATH/run/lib.sh

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

		b)
			if [ "$tests_passing" == "" ]; then
				# echo "Test unencrypted unsigned image"
				tests_passing+="Test install operator|Test uninstall operator|Test unencrypted unsigned image"
			else
				# echo "|Test unencrypted unsigned image"
				tests_passing+="|Test unencrypted unsigned image"
			fi
			;;
		e)
			if [ "$tests_passing" == "" ]; then
				# echo "Test encrypted image"
				tests_passing+="Test install operator|Test uninstall operator|Test encrypted image"
			else
				# echo "|Test encrypted image"
				tests_passing+="|Test encrypted image"
			fi
			;;
		s)
			if [ "$tests_passing" == "" ]; then
				# echo "Test signed image"
				tests_passing+="Test install operator|Test uninstall operator|Test signed image"
			else
				# echo "|Test signed image"
				tests_passing+="|Test signed image"
			fi
			;;
		t)
			if [ "$tests_passing" == "" ]; then
				# echo "Test trust storage"
				tests_passing+="Test install operator|Test uninstall operator|Test trust storage"
			else
				# echo "|Test trust storage"
				tests_passing+="|Test trust storage"
			fi
			;;
		o)
			if [ "$tests_passing" == "" ]; then
				# echo "Test trust storage"
				tests_passing+="Test install operator|Test uninstall operator"
			else
				# echo "|Test trust storage"
				tests_passing+="|Test uninstall operator|Test uninstall operator"
			fi
			;;
		h) usage 0 ;;
		*)
			echo "Invalid option: -$OPTARG" >&2
			usage 1
			;;
		esac
	done
}

run_non_tee_tests() {

	echo $tests_passing
	bats -f "$tests_passing" \
		"k8s_non_tee_cc.bats"

}
print_image() {
	IMAGES=($1)
	for IMAGE in "${IMAGES[@]}"; do
		echo "    $IMAGE $(docker image ls | grep $IMAGE | head -1 | awk '{print $7}')"
	done
}
main() {
	parse_args $@
	$TEST_PATH/serverinfo/serverinfo-stdout.sh
	echo -e "\n\n"
	echo "--------Operator Version--------"
	OPERATOR_VERSION=$(jq -r .file.operator_version $TEST_PATH/config/test_config.json)
	echo "Operator Version: $OPERATOR_VERSION"

	echo -e "\n--------Test Images--------"

	EXAMPLE_IMAGE_LISTS=$(jq -r .file.comments_image_lists[] $TEST_PATH/config/test_config.json)
	echo -e "unsigned unencrpted images: "
	print_image "${EXAMPLE_IMAGE_LISTS[@]}"
	echo -e "trust storage images: "
	print_image "${EXAMPLE_IMAGE_LISTS[@]}"
	echo -e "signed images: "
	print_image "${EXAMPLE_IMAGE_LISTS[@]}"
	echo -e "\n\n"
	echo "install Kubernetes"
	# exit 0
	# $TEST_PATH/setup/setup.sh
	run_non_tee_tests

}

main "$@"
