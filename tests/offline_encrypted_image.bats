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



@test "Test_offline_encrypted_image ubuntu 77.8MB kata-qemu" {
	
	set_runtimeclass_config kata-qemu
	generate_offline_encrypted_image ubuntu
	setup_offline_decryption_files_in_guest
	pod_config="$(new_pod_config_normal ${TEST_COCO_PATH}/../fixtures/offline-encrypted-config.yaml.in "ubuntu" "kata-qemu" "zcy-Z390-AORUS-MASTER.sh.intel.com/ubuntu:offline-encrypted")"
	pull_encrypted_image_inside_guest_with_decryption_key $pod_config
	rm $pod_config
}
@test "Test_offline_encrypted_image ubuntu 77.8MB kata-clh" {
	
	set_runtimeclass_config kata-clh
	generate_offline_encrypted_image ubuntu
	setup_offline_decryption_files_in_guest
	pod_config="$(new_pod_config_normal ${TEST_COCO_PATH}/../fixtures/offline-encrypted-config.yaml.in "ubuntu" "kata-clh" "zcy-Z390-AORUS-MASTER.sh.intel.com/ubuntu:offline-encrypted")"
	pull_encrypted_image_inside_guest_with_decryption_key $pod_config
	rm $pod_config
}
@test "Test_offline_encrypted_image nginx 142MB kata-qemu" {
	
	set_runtimeclass_config kata-qemu
	generate_offline_encrypted_image nginx
	setup_offline_decryption_files_in_guest
	pod_config="$(new_pod_config_normal ${TEST_COCO_PATH}/../fixtures/offline-encrypted-config.yaml.in "nginx" "kata-qemu" "zcy-Z390-AORUS-MASTER.sh.intel.com/nginx:offline-encrypted")"
	pull_encrypted_image_inside_guest_with_decryption_key $pod_config
	rm $pod_config
}
@test "Test_offline_encrypted_image nginx 142MB kata-clh" {
	
	set_runtimeclass_config kata-clh
	generate_offline_encrypted_image nginx
	setup_offline_decryption_files_in_guest
	pod_config="$(new_pod_config_normal ${TEST_COCO_PATH}/../fixtures/offline-encrypted-config.yaml.in "nginx" "kata-clh" "zcy-Z390-AORUS-MASTER.sh.intel.com/nginx:offline-encrypted")"
	pull_encrypted_image_inside_guest_with_decryption_key $pod_config
	rm $pod_config
}
@test "Test uninstall operator" {
	reset_runtime
}
