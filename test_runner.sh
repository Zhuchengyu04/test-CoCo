set -o errexit
set -o nounset
set -o pipefail
TEST_PATH=$(pwd)
script_name=$(basename "$0")
tests_passing=""
tests_config=""
tests_flag=""
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
	read_config

	while getopts "uestabmiopch :" opt; do
		case $opt in

		u)
			run_multiple_pod_spec_amd_images_config
			# tests_passing+="|Test unencrypted unsigned image"
			;;
		e)
			run_encrypted_image_config
			# tests_passing+="|Test encrypted image"
			;;
		s)
			run_signed_image_config
			# tests_passing+="|Test signed image"
			;;
		t)
			run_trust_storage_config
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
	echo $tests_config
	# echo $tests_passing
}
generate_tests() {
	local base_config="$TEST_COCO_PATH/../templates/multiple_pod_spec_and_images.template"
	local new_config=$(mktemp "$TEST_COCO_PATH/../tests/$(basename ${base_config}).XXX")

	IMAGE="$1" IMAGE_SIZE="$2" RUNTIMECLASSNAME="$3" REGISTRTYIMAGE="$REGISTRY_NAME/$1:$VERSION" POD_CPU_NUM="$4" POD_MEM_SIZE="$5" pod_config="\$pod_config" TEST_COCO_PATH="\$TEST_COCO_PATH" envsubst <"$base_config" >"$new_config"

	echo "$new_config"
}
generate_tests_trust_storage() {
	local base_config=$1
	local new_config=$(mktemp "$TEST_COCO_PATH/../tests/$(basename ${base_config}).XXX")

	IMAGE="$2" IMAGE_SIZE="$3" RUNTIMECLASSNAME="$4" REGISTRTYIMAGE="$REGISTRY_NAME/$2:$VERSION" pod_config="\$pod_config" go_path="\$GOPATH" test_coco_path="\$TEST_COCO_PATH" POD_NAME="\${POD_NAME}" pod_config_snap="\$pod_config_snap" snap_metadata_name="\$snap_metadata_name" SNAP_POD_NAME="\${SNAP_POD_NAME}" envsubst <"$base_config" >"$new_config"

	echo "$new_config"
}
generate_tests_signed_image() {
	local base_config=$1
	local new_config=$(mktemp "$TEST_COCO_PATH/../tests/$(basename ${base_config}).XXX")

	IMAGE="$2" IMAGE_SIZE="$3" RUNTIMECLASSNAME="$4" REGISTRTYIMAGE="$REGISTRY_NAME/$2" pod_config="\$pod_config" test_coco_path="\${TEST_COCO_PATH}" pod_id="\$pod_id" envsubst <"$base_config" >"$new_config"

	echo "$new_config"
}
generate_tests_encrypted_image() {
	local base_config=$1
	local new_config=$(mktemp "$TEST_COCO_PATH/../tests/$(basename ${base_config}).XXX")

	IMAGE="$2" IMAGE_SIZE="$3" RUNTIMECLASSNAME="$4" REGISTRTYIMAGE="$REGISTRY_NAME/$2" pod_config="\$pod_config" test_coco_path="\${TEST_COCO_PATH}" VERDICTDID="\$VERDICTDID" envsubst <"$base_config" >"$new_config"

	echo "$new_config"
}
run_multiple_pod_spec_amd_images_config() {
	local pod_configs="$TEST_COCO_PATH/../templates/multiple_pod_spec_and_images.bats"
	local new_pod_configs="$TEST_COCO_PATH/../tests/$(basename ${pod_configs})"
	local str="Test_multiple_pod_spec_and_images"
	tests_passing="Test install operator"
	cp $pod_configs $new_pod_configs
	for image in ${EXAMPLE_IMAGE_LISTS[@]}; do
		docker pull $image
		image_size=$(docker image ls | grep $image | head -1 | awk '{print $7}')
		for runtimeclass in ${RUNTIMECLASS[@]}; do
			for cpunums in ${CPUCONFIG[@]}; do
				for memsize in ${MEMCONFIG[@]}; do
					cat "$(generate_tests $image $image_size $runtimeclass $cpunums $memsize)" | tee -a $new_pod_configs
					tests_passing+="|${str} $image $image_size $runtimeclass ${cpunums} ${memsize}GB"
				done
			done
		done
	done
	cat "$TEST_COCO_PATH/../templates/operator.bats" | tee -a $new_pod_configs
	tests_passing+="|Test uninstall operator"

	bats -f "$tests_passing" \
		"$TEST_COCO_PATH/../tests/multiple_pod_spec_and_images.bats"
	rm -rf $TEST_COCO_PATH/../tests/*
	rm -rf $TEST_COCO_PATH/../fixtures/multiple_pod_spec_and_images-config.yaml.in.*
}
run_trust_storage_config() {
	local pod_configs="$TEST_COCO_PATH/../templates/trust_storage.bats"
	local new_pod_configs="$TEST_COCO_PATH/../tests/$(basename ${pod_configs})"
	local str="Test_trust_storage"
	tests_passing="Test install operator"
	cp $pod_configs $new_pod_configs
	for image in ${EXAMPLE_IMAGE_LISTS[@]}; do
		docker pull $image
		image_size=$(docker image ls | grep $image | head -1 | awk '{print $7}')
		for runtimeclass in ${RUNTIMECLASS[@]}; do
			cat "$(generate_tests_trust_storage "$TEST_COCO_PATH/../templates/trust_storage.template" $image $image_size $runtimeclass)" | tee -a $new_pod_configs
			tests_passing+="|${str} $image $image_size $runtimeclass "

		done
	done
	cat "$TEST_COCO_PATH/../templates/operator_trust_storage.bats" | tee -a $new_pod_configs
	tests_passing+="|Test uninstall operator"

	bats -f "$tests_passing" \
		"$TEST_COCO_PATH/../tests/trust_storage.bats"
	rm -rf $TEST_COCO_PATH/../tests/*
}
run_signed_image_config() {
	local pod_configs="$TEST_COCO_PATH/../templates/multiple_pod_spec_and_images.bats"
	local new_pod_configs="$TEST_COCO_PATH/../tests/signed_image.bats"
	local str="Test_signed_image"
	tests_passing="Test install operator"
	cp $pod_configs $new_pod_configs
	for image in ${EXAMPLE_IMAGE_LISTS[@]}; do
		docker pull $image
		image_size=$(docker image ls | grep $image | head -1 | awk '{print $7}')
		for runtimeclass in ${RUNTIMECLASS[@]}; do
			cat "$(generate_tests_signed_image "$TEST_COCO_PATH/../templates/signed_image.template" $image $image_size $runtimeclass)" | tee -a $new_pod_configs
			tests_passing+="|${str} $image $image_size $runtimeclass"
		done
	done
	cat "$TEST_COCO_PATH/../templates/operator.bats" | tee -a $new_pod_configs
	tests_passing+="|Test uninstall operator"

	bats -f "$tests_passing" \
		"$TEST_COCO_PATH/../tests/signed_image.bats"
	rm -rf $TEST_COCO_PATH/../tests/*
	rm -rf $TEST_COCO_PATH/../fixtures/signed_image-config.yaml.in.*
}
run_encrypted_image_config() {
	local pod_configs="$TEST_COCO_PATH/../templates/multiple_pod_spec_and_images.bats"
	local new_pod_configs="$TEST_COCO_PATH/../tests/encrypted_image.bats"
	local str="Test_encrypted_image"
	tests_passing="Test install operator"
	cp $pod_configs $new_pod_configs
	for image in ${EXAMPLE_IMAGE_LISTS[@]}; do
		docker pull $image
		image_size=$(docker image ls | grep $image | head -1 | awk '{print $7}')
		for runtimeclass in ${RUNTIMECLASS[@]}; do
			cat "$(generate_tests_encrypted_image "$TEST_COCO_PATH/../templates/encrypted_image.template" $image $image_size $runtimeclass)" | tee -a $new_pod_configs
			tests_passing+="|${str} $image $image_size $runtimeclass"
		done
	done
	cat "$TEST_COCO_PATH/../templates/operator.bats" | tee -a $new_pod_configs
	tests_passing+="|Test uninstall operator"

	bats -f "$tests_passing" \
		"$TEST_COCO_PATH/../tests/encrypted_image.bats"
	rm -rf $TEST_COCO_PATH/../tests/*
	rm -rf $TEST_COCO_PATH/../fixtures/encrypted_image-config.yaml.in.*
}
print_image() {
	IMAGES=($1)
	for IMAGE in "${IMAGES[@]}"; do
		echo "    $IMAGE $(docker image ls | grep $IMAGE | head -1 | awk '{print $7}')"
	done
}
main() {

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
	if [ -f /etc/systemd/system/containerd.service.d/containerd-for-cc-override.conf ]; then
		rm /etc/systemd/system/containerd.service.d/containerd-for-cc-override.conf
	fi
	parse_args $@

}

main "$@"
