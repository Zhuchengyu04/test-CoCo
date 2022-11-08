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



@test "Test_encrypted_image ubuntu 77.8MB kata-qemu" {

	# skip  "need to rebuild rootfs including eaa_bkc and guest kernel to test encrypted image, which is not supported in branch main of operator"
	generate_encrypted_image
	VERDICTDID=$(ps ux | grep "verdictd" | grep -v "grep" | awk '{print $2}')
	if [ "$VERDICTDID" == "" ]; then
		verdictd --listen 0.0.0.0:50000 --mutual >/dev/null 2>&1 &
	fi
	sleep 1
	setup_decryption_files_in_guest
	pod_config="$(new_pod_config_normal /../fixtures/encrypted_image-config.yaml.in "ubuntu" "kata-qemu" "zcy-Z390-AORUS-MASTER.sh.intel.com/ubuntu:encrypted")"
	pull_encrypted_image_inside_guest_with_decryption_key $pod_config
	# assert_pod_fail "$pod_config"
	rm $pod_config
	VERDICTDID=$(ps ux | grep "verdictd " | grep -v "grep" | awk '{print $2}')
	echo $VERDICTDID
	kill -9 $VERDICTDID
}
@test "Test_encrypted_image ubuntu 77.8MB kata-clh" {

	# skip  "need to rebuild rootfs including eaa_bkc and guest kernel to test encrypted image, which is not supported in branch main of operator"
	generate_encrypted_image
	VERDICTDID=$(ps ux | grep "verdictd" | grep -v "grep" | awk '{print $2}')
	if [ "$VERDICTDID" == "" ]; then
		verdictd --listen 0.0.0.0:50000 --mutual >/dev/null 2>&1 &
	fi
	sleep 1
	setup_decryption_files_in_guest
	pod_config="$(new_pod_config_normal /../fixtures/encrypted_image-config.yaml.in "ubuntu" "kata-clh" "zcy-Z390-AORUS-MASTER.sh.intel.com/ubuntu:encrypted")"
	pull_encrypted_image_inside_guest_with_decryption_key $pod_config
	# assert_pod_fail "$pod_config"
	rm $pod_config
	VERDICTDID=$(ps ux | grep "verdictd " | grep -v "grep" | awk '{print $2}')
	echo $VERDICTDID
	kill -9 $VERDICTDID
}
@test "Test_encrypted_image nginx 142MB kata-qemu" {

	# skip  "need to rebuild rootfs including eaa_bkc and guest kernel to test encrypted image, which is not supported in branch main of operator"
	generate_encrypted_image
	VERDICTDID=$(ps ux | grep "verdictd" | grep -v "grep" | awk '{print $2}')
	if [ "$VERDICTDID" == "" ]; then
		verdictd --listen 0.0.0.0:50000 --mutual >/dev/null 2>&1 &
	fi
	sleep 1
	setup_decryption_files_in_guest
	pod_config="$(new_pod_config_normal /../fixtures/encrypted_image-config.yaml.in "nginx" "kata-qemu" "zcy-Z390-AORUS-MASTER.sh.intel.com/nginx:encrypted")"
	pull_encrypted_image_inside_guest_with_decryption_key $pod_config
	# assert_pod_fail "$pod_config"
	rm $pod_config
	VERDICTDID=$(ps ux | grep "verdictd " | grep -v "grep" | awk '{print $2}')
	echo $VERDICTDID
	kill -9 $VERDICTDID
}
@test "Test_encrypted_image nginx 142MB kata-clh" {

	# skip  "need to rebuild rootfs including eaa_bkc and guest kernel to test encrypted image, which is not supported in branch main of operator"
	generate_encrypted_image
	VERDICTDID=$(ps ux | grep "verdictd" | grep -v "grep" | awk '{print $2}')
	if [ "$VERDICTDID" == "" ]; then
		verdictd --listen 0.0.0.0:50000 --mutual >/dev/null 2>&1 &
	fi
	sleep 1
	setup_decryption_files_in_guest
	pod_config="$(new_pod_config_normal /../fixtures/encrypted_image-config.yaml.in "nginx" "kata-clh" "zcy-Z390-AORUS-MASTER.sh.intel.com/nginx:encrypted")"
	pull_encrypted_image_inside_guest_with_decryption_key $pod_config
	# assert_pod_fail "$pod_config"
	rm $pod_config
	VERDICTDID=$(ps ux | grep "verdictd " | grep -v "grep" | awk '{print $2}')
	echo $VERDICTDID
	kill -9 $VERDICTDID
}
@test "Test uninstall operator" {
	reset_runtime
}
