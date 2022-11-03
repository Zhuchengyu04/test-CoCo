set -o errexit
set -o nounset
set -o pipefail
TEST_PATH=$(pwd)
script_name=$(basename "$0")
tests_passing=""
tests_config=""
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
			# tests_passing+="|Test unencrypted unsigned image"
			tests_config="Test_multiple_pod_spec_and_images: "
			;;
		e)

			# tests_passing+="|Test encrypted image"
			;;
		s)
			# tests_passing+="|Test signed image"
			;;
		t)

			# tests_passing+="|Test trust storage"
			;;
		n)
			# tests_passing+="|Test attestation"
			;;
		b)

			# tests_passing+="|Test measured boot"
			;;
		m)

			# tests_passing+="|Test multiple registries"
			;;
		i)

			# tests_passing+="|Test image sharing"
			;;
		o)
			# tests_passing+="|Test OnDemand image pulling"
			;;
		p)

			# tests_passing+="|Test TD preserving"
			;;
		c)

			# tests_passing+="|Test common cloud native projects"
			;;
		a)
			# tests_passing+="|Test unencrypted unsigned image"
			# tests_passing+="|Test encrypted image"
			# tests_passing+="|Test signed image"
			# tests_passing+="|Test trust storage"
			# tests_passing+="|Test attestation"
			# tests_passing+="|Test measured boot"
			# tests_passing+="|Test multiple registries"
			# tests_passing+="|Test image sharing"
			# tests_passing+="|Test OnDemand image pulling"
			# tests_passing+="|Test TD preserving"
			# tests_passing+="|Test common cloud native projects"
			;;
		h) usage 0 ;;
		*)
			echo "Invalid option: -$OPTARG" >&2
			usage 1
			;;
		esac
	done
	
	echo $tests_passing
}
generate_tests() {
	local base_config="$TEST_COCO_PATH/../templates/multiple_pod_spec_and_images.template"
	local new_config=$(mktemp "$TEST_COCO_PATH/../tests/$(basename ${base_config}).XXX")

	IMAGE="$1" IMAGE_SIZE="$2" RUNTIMECLASSNAME="$3" REGISTRTYIMAGE="$REGISTRY_NAME/$1:$VERSION" POD_CPU_NUM="$4" POD_MEM_SIZE="$5" pod_config="\$pod_config" TEST_COCO_PATH="\$TEST_COCO_PATH" envsubst <"$base_config" >"$new_config"

	echo "$new_config"
}
run_non_tee_tests() {
	read_config
	tests_config="Test_multiple_pod_spec_and_images"
	if [ "$tests_config" == "Test_multiple_pod_spec_and_images" ]; then
		local pod_configs="$TEST_COCO_PATH/../templates/multiple_pod_spec_and_images.bats"
		local new_pod_configs="$TEST_COCO_PATH/../tests/$(basename ${pod_configs})"
		cp $pod_configs $new_pod_configs
		for image in ${EXAMPLE_IMAGE_LISTS[@]}; do
			image_size=$(docker image ls | grep $IMAGE | head -1 | awk '{print $7}')
			for runtimeclass in ${RUNTIMECLASS[@]}; do
				for cpunums in ${CPUCONFIG[@]}; do
					for memsize in ${MEMCONFIG[@]}; do
						cat "$(generate_tests $image $image_size $runtimeclass $cpunums $memsize)"| tee -a  $new_pod_configs
						tests_passing+="|${tests_config} $image $image_size $runtimeclass $cpunums ${memsize}GB"
						# exit 0
					done
				done
			done
		done
		cat "$TEST_COCO_PATH/../templates/operator.bats" | tee -a  $new_pod_configs
		tests_passing+="|Test uninstall operator"
		echo $tests_passing
		bats -f "$tests_passing" \
			"$TEST_COCO_PATH/../tests/multiple_pod_spec_and_images.bats"
		rm -f $TEST_COCO_PATH/../tests/*
	fi

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
	OPERATOR_VERSION=$(jq -r .file.operatorVersion $TEST_PATH/config/test_config.json)
	echo "Operator Version: $OPERATOR_VERSION"

	echo -e "\n--------Test Cases--------"

	EXAMPLE_IMAGE_LISTS=$(jq -r .file.commentsImageLists[] $TEST_PATH/config/test_config.json)
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
	# $TEST_PATH/setup/setup.sh
	run_non_tee_tests

}

main "$@"
