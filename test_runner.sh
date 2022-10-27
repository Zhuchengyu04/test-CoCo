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
	-u:	Multiple pod spec and container image tests
	-e:	Encrypted image tests
	-s:	Signed image tests
	-t:	Trusted storage for container image tests
	-n:	Attestation tests
	-b:	Measured boot tests
	-m:	Multiple registries tests
	-i:	Image sharing tests
	-o:	OnDemand image pulling tests
	-p:	TD preserving tests
	-c:	Common Cloud Native projects tests
	-a:	All tests
	-h:	help
EOF
}
parse_args() {
	tests_passing+="Test install operator"
	while getopts "uestabmiopch :" opt; do
		case $opt in

		u)
			tests_passing+="|Test unencrypted unsigned image"
			;;
		e)

			tests_passing+="|Test encrypted image"
			;;
		s)
			tests_passing+="|Test signed image"
			;;
		t)

			tests_passing+="|Test trust storage"
			;;
		n)
			tests_passing+="|Test attestation"
			;;
		b)

			tests_passing+="|Test measured boot"
			;;
		m)

			tests_passing+="|Test multiple registries"
			;;
		i)

			tests_passing+="|Test image sharing"
			;;
		o)
			tests_passing+="|Test OnDemand image pulling"
			;;
		p)

			tests_passing+="|Test TD preserving"
			;;
		c)

			tests_passing+="|Test common cloud native projects"
			;;
		a)
			tests_passing+="|Test unencrypted unsigned image"
			tests_passing+="|Test encrypted image"
			tests_passing+="|Test signed image"
			tests_passing+="|Test trust storage"
			tests_passing+="|Test attestation"
			tests_passing+="|Test measured boot"
			tests_passing+="|Test multiple registries"
			tests_passing+="|Test image sharing"
			tests_passing+="|Test OnDemand image pulling"
			tests_passing+="|Test TD preserving"
			tests_passing+="|Test common cloud native projects"
			;;
		h) usage 0 ;;
		*)
			echo "Invalid option: -$OPTARG" >&2
			usage 1
			;;
		esac
	done
	tests_passing+="|Test uninstall operator"
	echo $tests_passing
}

run_non_tee_tests() {

	
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

	echo -e "\n--------Test Cases--------"

	EXAMPLE_IMAGE_LISTS=$(jq -r .file.comments_image_lists[] $TEST_PATH/config/test_config.json)
	echo -e "unsigned unencrpted images: "
	print_image "${EXAMPLE_IMAGE_LISTS[@]}"
	echo -e "trust storage images: "
	print_image "${EXAMPLE_IMAGE_LISTS[@]}"
	echo -e "signed images: "
	print_image "${EXAMPLE_IMAGE_LISTS[@]}"
	echo -e "encrypted images: "
	print_image "${EXAMPLE_IMAGE_LISTS[@]}"
	echo -e "Attestation: TODO"
	echo -e "Measured boot: TODO"
	echo -e "Multiple registries: TODO"
	echo -e "Image sharing: TODO"
	echo -e "OnDemand image pulling: TODO"
	echo -e "TD Preserving: TODO"
	echo -e "Common Cloud Native projects: TODO"
	echo -e "\n\n"
	echo "install Kubernetes"
	# exit 0
	# $TEST_PATH/setup/setup.sh
	run_non_tee_tests

}

main "$@"
