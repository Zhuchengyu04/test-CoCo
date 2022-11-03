#!/usr/bin/env bats

load ../run/lib.sh
load ../run/cc_deploy.sh

test_tag="[cc][agent][kubernetes][containerd]"

setup() {
	start_date=$(date +"%Y-%m-%d %H:%M:%S")

}


@test "Test install operator" {
	install_runtime
	echo "Prepare containerd for Confidential Container"

	read_config
	echo "Reconfigure Kata Containers"

	switch_image_service_offload on
	add_kernel_params "agent.log=debug"
	add_kernel_params "debug_console_enabled=true"
	run_registry

	$TEST_COCO_PATH/../run/losetup-crt.sh $ROOTFS_IMAGE_PATH c
}



teardown() {

	restore
	#reset_runtime
	# gpg --delete-keys $GPG_EMAIL
	# gpg --delete-secret-keys $GPG_EMAIL
	REGISTRY_CONTAINER=$(docker ps -a | grep "registry" | awk '{print $1}')
	if [ -n "$REGISTRY_CONTAINER" ]; then
		docker stop $REGISTRY_CONTAINER
		docker rm $REGISTRY_CONTAINER
	fi

}


@test "Test_multiple_pod_spec_and_images ubuntu 117MB kata-qemu 1 1GB" {
		pod_config="$(new_pod_config $TEST_COCO_PATH/../fixtures/multiple_pod_spec_and_images-config.yaml.in "ubuntu" "kata-qemu" "zcy-Z390-AORUS-MASTER.sh.intel.com/ubuntu:latest" "1" "1")"

		unencrypted_signed_image_from_unprotected_registry $pod_config
		rm $pod_config
}

@test "Test_multiple_pod_spec_and_images ubuntu 117MB kata-qemu 1 2GB" {
		pod_config="$(new_pod_config $TEST_COCO_PATH/../fixtures/multiple_pod_spec_and_images-config.yaml.in "ubuntu" "kata-qemu" "zcy-Z390-AORUS-MASTER.sh.intel.com/ubuntu:latest" "1" "2")"

		unencrypted_signed_image_from_unprotected_registry $pod_config
		rm $pod_config
}

@test "Test_multiple_pod_spec_and_images ubuntu 117MB kata-qemu 2 1GB" {
		pod_config="$(new_pod_config $TEST_COCO_PATH/../fixtures/multiple_pod_spec_and_images-config.yaml.in "ubuntu" "kata-qemu" "zcy-Z390-AORUS-MASTER.sh.intel.com/ubuntu:latest" "2" "1")"

		unencrypted_signed_image_from_unprotected_registry $pod_config
		rm $pod_config
}

@test "Test_multiple_pod_spec_and_images ubuntu 117MB kata-qemu 2 2GB" {
		pod_config="$(new_pod_config $TEST_COCO_PATH/../fixtures/multiple_pod_spec_and_images-config.yaml.in "ubuntu" "kata-qemu" "zcy-Z390-AORUS-MASTER.sh.intel.com/ubuntu:latest" "2" "2")"

		unencrypted_signed_image_from_unprotected_registry $pod_config
		rm $pod_config
}

@test "Test_multiple_pod_spec_and_images ubuntu 117MB kata-clh 1 1GB" {
		pod_config="$(new_pod_config $TEST_COCO_PATH/../fixtures/multiple_pod_spec_and_images-config.yaml.in "ubuntu" "kata-clh" "zcy-Z390-AORUS-MASTER.sh.intel.com/ubuntu:latest" "1" "1")"

		unencrypted_signed_image_from_unprotected_registry $pod_config
		rm $pod_config
}

@test "Test_multiple_pod_spec_and_images ubuntu 117MB kata-clh 1 2GB" {
		pod_config="$(new_pod_config $TEST_COCO_PATH/../fixtures/multiple_pod_spec_and_images-config.yaml.in "ubuntu" "kata-clh" "zcy-Z390-AORUS-MASTER.sh.intel.com/ubuntu:latest" "1" "2")"

		unencrypted_signed_image_from_unprotected_registry $pod_config
		rm $pod_config
}

@test "Test_multiple_pod_spec_and_images ubuntu 117MB kata-clh 2 1GB" {
		pod_config="$(new_pod_config $TEST_COCO_PATH/../fixtures/multiple_pod_spec_and_images-config.yaml.in "ubuntu" "kata-clh" "zcy-Z390-AORUS-MASTER.sh.intel.com/ubuntu:latest" "2" "1")"

		unencrypted_signed_image_from_unprotected_registry $pod_config
		rm $pod_config
}

@test "Test_multiple_pod_spec_and_images ubuntu 117MB kata-clh 2 2GB" {
		pod_config="$(new_pod_config $TEST_COCO_PATH/../fixtures/multiple_pod_spec_and_images-config.yaml.in "ubuntu" "kata-clh" "zcy-Z390-AORUS-MASTER.sh.intel.com/ubuntu:latest" "2" "2")"

		unencrypted_signed_image_from_unprotected_registry $pod_config
		rm $pod_config
}

@test "Test_multiple_pod_spec_and_images redis 117MB kata-qemu 1 1GB" {
		pod_config="$(new_pod_config $TEST_COCO_PATH/../fixtures/multiple_pod_spec_and_images-config.yaml.in "redis" "kata-qemu" "zcy-Z390-AORUS-MASTER.sh.intel.com/redis:latest" "1" "1")"

		unencrypted_signed_image_from_unprotected_registry $pod_config
		rm $pod_config
}

@test "Test_multiple_pod_spec_and_images redis 117MB kata-qemu 1 2GB" {
		pod_config="$(new_pod_config $TEST_COCO_PATH/../fixtures/multiple_pod_spec_and_images-config.yaml.in "redis" "kata-qemu" "zcy-Z390-AORUS-MASTER.sh.intel.com/redis:latest" "1" "2")"

		unencrypted_signed_image_from_unprotected_registry $pod_config
		rm $pod_config
}

@test "Test_multiple_pod_spec_and_images redis 117MB kata-qemu 2 1GB" {
		pod_config="$(new_pod_config $TEST_COCO_PATH/../fixtures/multiple_pod_spec_and_images-config.yaml.in "redis" "kata-qemu" "zcy-Z390-AORUS-MASTER.sh.intel.com/redis:latest" "2" "1")"

		unencrypted_signed_image_from_unprotected_registry $pod_config
		rm $pod_config
}

@test "Test_multiple_pod_spec_and_images redis 117MB kata-qemu 2 2GB" {
		pod_config="$(new_pod_config $TEST_COCO_PATH/../fixtures/multiple_pod_spec_and_images-config.yaml.in "redis" "kata-qemu" "zcy-Z390-AORUS-MASTER.sh.intel.com/redis:latest" "2" "2")"

		unencrypted_signed_image_from_unprotected_registry $pod_config
		rm $pod_config
}

@test "Test_multiple_pod_spec_and_images redis 117MB kata-clh 1 1GB" {
		pod_config="$(new_pod_config $TEST_COCO_PATH/../fixtures/multiple_pod_spec_and_images-config.yaml.in "redis" "kata-clh" "zcy-Z390-AORUS-MASTER.sh.intel.com/redis:latest" "1" "1")"

		unencrypted_signed_image_from_unprotected_registry $pod_config
		rm $pod_config
}

@test "Test_multiple_pod_spec_and_images redis 117MB kata-clh 1 2GB" {
		pod_config="$(new_pod_config $TEST_COCO_PATH/../fixtures/multiple_pod_spec_and_images-config.yaml.in "redis" "kata-clh" "zcy-Z390-AORUS-MASTER.sh.intel.com/redis:latest" "1" "2")"

		unencrypted_signed_image_from_unprotected_registry $pod_config
		rm $pod_config
}

@test "Test_multiple_pod_spec_and_images redis 117MB kata-clh 2 1GB" {
		pod_config="$(new_pod_config $TEST_COCO_PATH/../fixtures/multiple_pod_spec_and_images-config.yaml.in "redis" "kata-clh" "zcy-Z390-AORUS-MASTER.sh.intel.com/redis:latest" "2" "1")"

		unencrypted_signed_image_from_unprotected_registry $pod_config
		rm $pod_config
}

@test "Test_multiple_pod_spec_and_images redis 117MB kata-clh 2 2GB" {
		pod_config="$(new_pod_config $TEST_COCO_PATH/../fixtures/multiple_pod_spec_and_images-config.yaml.in "redis" "kata-clh" "zcy-Z390-AORUS-MASTER.sh.intel.com/redis:latest" "2" "2")"

		unencrypted_signed_image_from_unprotected_registry $pod_config
		rm $pod_config
}
@test "Test uninstall operator" {
	reset_runtime
}