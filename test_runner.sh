set -o errexit
set -o nounset
set -o pipefail
TEST_PATH=$(pwd)
script_name=$(basename "$0")
tests_passing=""
tests_config=""
tests_flag=""
source $TEST_PATH/run/lib.sh
source $TEST_PATH/run/cc_deploy.sh

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

	while getopts "uestabmiopfch :" opt; do
		case $opt in

		u)
			run_multiple_pod_spec_and_images_config
			;;
		e)
			run_encrypted_image_config
			;;
		s)
			run_signed_image_config
			;;
		t)
			run_trust_storage_config
			;;
		n) ;;

		b) ;;

		m) ;;

		i) ;;

		o) ;;

		p) ;;
		f)
			run_offline_encrypted_image_config
			;;
		c)
			run_cosigned_image_config
			;;
		d) ;;

		a)
			run_multiple_pod_spec_and_images_config
			run_encrypted_image_config
			run_offline_encrypted_image_config
			run_signed_image_config
			run_cosigned_image_config
			run_trust_storage_config
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

	IMAGE="$1" IMAGE_SIZE="$2" RUNTIMECLASSNAME="$3" REGISTRTYIMAGE="$REGISTRY_NAME:$PORT/$1:$VERSION" POD_CPU_NUM="$4" POD_MEM_SIZE="$5" pod_config="\$pod_config" TEST_COCO_PATH="\$TEST_COCO_PATH" envsubst <"$base_config" >"$new_config"

	echo "$new_config"
}

run_multiple_pod_spec_and_images_config() {
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
					cat "$(generate_tests $image $image_size $runtimeclass $cpunums $memsize)" | tee -a $new_pod_configs >/dev/null 2>&1
					tests_passing+="|${str} $image $image_size $runtimeclass ${cpunums} ${memsize}GB"
				done
			done
		done
	done
	cat "$TEST_COCO_PATH/../templates/operator.bats" | tee -a $new_pod_configs >/dev/null 2>&1
	tests_passing+="|Test uninstall operator"

	bats -f "$tests_passing" \
		"$TEST_COCO_PATH/../tests/multiple_pod_spec_and_images.bats" -F junit
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
			cat "$(generate_tests_trust_storage "$TEST_COCO_PATH/../templates/trust_storage.template" $image $image_size $runtimeclass)" | tee -a $new_pod_configs >/dev/null 2>&1
			tests_passing+="|${str} $image $image_size $runtimeclass "

		done
	done
	cat "$TEST_COCO_PATH/../templates/operator_trust_storage.bats" | tee -a $new_pod_configs >/dev/null 2>&1
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
			cat "$(generate_tests_signed_image "$TEST_COCO_PATH/../templates/signed_image.template" $image $image_size $runtimeclass)" | tee -a $new_pod_configs >/dev/null 2>&1
			tests_passing+="|${str} $image $image_size $runtimeclass"
		done
	done
	cat "$TEST_COCO_PATH/../templates/operator.bats" | tee -a $new_pod_configs >/dev/null 2>&1
	tests_passing+="|Test uninstall operator"

	bats -f "$tests_passing" \
		"$TEST_COCO_PATH/../tests/signed_image.bats" -F junit
	rm -rf $TEST_COCO_PATH/../tests/*
	rm -rf $TEST_COCO_PATH/../fixtures/signed_image-config.yaml.in.*
}
run_cosigned_image_config() {
	local pod_configs="$TEST_COCO_PATH/../templates/multiple_pod_spec_and_images.bats"
	local new_pod_configs="$TEST_COCO_PATH/../tests/cosigned_image.bats"
	local str="Test_cosigned_image"
	tests_passing="Test install operator"
	cp $pod_configs $new_pod_configs
	for image in ${EXAMPLE_IMAGE_LISTS[@]}; do
		docker pull $image
		image_size=$(docker image ls | grep $image | head -1 | awk '{print $7}')

		for runtimeclass in ${RUNTIMECLASS[@]}; do
			cat "$(generate_tests_cosign_image "$TEST_COCO_PATH/../templates/cosigned_image.template" $image $image_size $runtimeclass)" | tee -a $new_pod_configs >/dev/null 2>&1
			tests_passing+="|${str} $image $image_size $runtimeclass"
		done
	done
	cat "$TEST_COCO_PATH/../templates/operator.bats" | tee -a $new_pod_configs >/dev/null 2>&1
	tests_passing+="|Test uninstall operator"

	bats -f "$tests_passing" \
		"$TEST_COCO_PATH/../tests/cosigned_image.bats"
	rm -rf $TEST_COCO_PATH/../tests/*
	rm -rf $TEST_COCO_PATH/../fixtures/cosign-config.yaml.in.*
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
			cat "$(generate_tests_encrypted_image "$TEST_COCO_PATH/../templates/encrypted_image.template" $image $image_size $runtimeclass)" | tee -a $new_pod_configs >/dev/null 2>&1
			tests_passing+="|${str} $image $image_size $runtimeclass"
		done
	done
	cat "$TEST_COCO_PATH/../templates/operator.bats" | tee -a $new_pod_configs >/dev/null 2>&1
	tests_passing+="|Test uninstall operator"

	bats -f "$tests_passing" \
		"$TEST_COCO_PATH/../tests/encrypted_image.bats"
	rm -rf $TEST_COCO_PATH/../tests/*
	rm -rf $TEST_COCO_PATH/../fixtures/encrypted_image-config.yaml.in.*
}
run_offline_encrypted_image_config() {
	local pod_configs="$TEST_COCO_PATH/../templates/multiple_pod_spec_and_images.bats"
	local new_pod_configs="$TEST_COCO_PATH/../tests/offline_encrypted_image.bats"
	local str="Test_offline_encrypted_image"
	tests_passing="Test install operator"
	cp $pod_configs $new_pod_configs
	for image in ${EXAMPLE_IMAGE_LISTS[@]}; do
		docker pull $image
		image_size=$(docker image ls | grep $image | head -1 | awk '{print $7}')
		for runtimeclass in ${RUNTIMECLASS[@]}; do
			cat "$(generate_tests_offline_encrypted_image "$TEST_COCO_PATH/../templates/offline_encrypted_image.template" $image $image_size $runtimeclass)" | tee -a $new_pod_configs >/dev/null 2>&1
			tests_passing+="|${str} $image $image_size $runtimeclass"
		done
	done
	cat "$TEST_COCO_PATH/../templates/operator.bats" | tee -a $new_pod_configs >/dev/null 2>&1
	tests_passing+="|Test uninstall operator"

	bats -f "$tests_passing" \
		"$TEST_COCO_PATH/../tests/offline_encrypted_image.bats" -F  tap
	rm -rf $TEST_COCO_PATH/../tests/*
	rm -rf $TEST_COCO_PATH/../fixtures/offline-encrypted-config.yaml.in.*
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
	
	echo -e "\n--------Functions to be tested with testing images--------"

	EXAMPLE_IMAGE_LISTS=$(jq -r .file.commentsImageLists[] $TEST_PATH/config/test_config.json)
	echo -e "multiple pod spec and images: "
	print_image "${EXAMPLE_IMAGE_LISTS[@]}"
	echo -e "trust storage images: "
	print_image "${EXAMPLE_IMAGE_LISTS[@]}"
	echo -e "signed images: "
	print_image "${EXAMPLE_IMAGE_LISTS[@]}"
	echo -e "encrypted images: "
	print_image "${EXAMPLE_IMAGE_LISTS[@]}"
	echo -e "offline-encrypted images: "
	print_image "${EXAMPLE_IMAGE_LISTS[@]}"
	echo -e "cosigned images: "
	print_image "${EXAMPLE_IMAGE_LISTS[@]}"
	echo -e "Attestation: TODO"
	echo -e "Measured boot: TODO"
	echo -e "Multiple registries: TODO"
	echo -e "Image sharing: TODO"
	echo -e "OnDemand image pulling: TODO"
	echo -e "TD Preserving: TODO"
	echo -e "Common Cloud Native projects: TODO"
	echo -e "\n"
	echo -e "-------Install Depedencies:-------\n"
	echo "install Kubernetes"
	echo "install bats"
	# git clone https://github.com/ChengyuZhu6/tests.git $GOPATH/src/github.com/kata-containers/tests >/dev/null
	# bash $GOPATH/src/github.com/kata-containers/tests/.ci/setup.sh >/dev/null 
	# $TEST_PATH/setup/install_bats.sh
	echo "--------Operator Version--------"
	OPERATOR_VERSION=$(jq -r .file.operatorVersion $TEST_PATH/config/test_config.json)
	echo "Operator Version: $OPERATOR_VERSION"
	# install_runtime  >/dev/null 2>&1
	# local kernel_version="$(/opt/confidential-containers/bin/kata-runtime kata-env --json | jq -r .Kernel.Path| cut -d '/' -f6)"
	# echo "Kernel: $kernel_version"
	# local runtime_version=$(/opt/confidential-containers/bin/kata-runtime kata-env --json | jq -r .Runtime.Version | grep Semver | cut -d'"' -f4)
	# echo "Runtime: $runtime_version"
	# local hypervisor_version=$(/opt/confidential-containers/bin/kata-runtime kata-env --json | jq -r .Hypervisor.Version| sed -n "1,1p")
	# echo "Hypervisor: $hypervisor_version"
	# reset_runtime  >/dev/null 2>&1
	echo -e "\n-------Test Result:-------"

	# $TEST_PATH/setup/setup.sh
	if [ -f /etc/systemd/system/containerd.service.d/containerd-for-cc-override.conf ]; then
		rm /etc/systemd/system/containerd.service.d/containerd-for-cc-override.conf
	fi
	parse_args $@

}

main "$@"
