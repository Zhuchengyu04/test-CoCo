#!/usr/bin/env bats

load ./lib.sh
load ./cc_deploy.sh

test_tag="[cc][agent][kubernetes][containerd]"

setup() {
	start_date=$(date +"%Y-%m-%d %H:%M:%S")


	install_runtime

	
	echo "Prepare containerd for Confidential Container"
	
	read_config
	echo "Reconfigure Kata Containers"

	clear_kernel_params
	switch_image_service_offload on
	add_kernel_params "agent.log=debug"
	add_kernel_params "debug_console_enabled=true"
	run_registry
	
	${FIXTURES_DIR}/../losetup-crt.sh $ROOTFS_IMAGE_PATH  c

}
@test "Test install operator" {
	reset_runtime
	install_runtime
}
@test "Test unencrypted unsigned image" {


	for IMAGE in ${EXAMPLE_IMAGE_LISTS[@]}; do
		checkout_pod_yaml "./fixtures/unsigned-unprotected-pod-config.yaml" $IMAGE
		unencrypted_signed_image_from_unprotected_registry $IMAGE

	done
	#kubectl delete -f "./fixtures/unsigned-unprotected-pod-config.yaml"
}
@test "Test trust storage" {
	${FIXTURES_DIR}/../losetup-crt.sh $ROOTFS_IMAGE_PATH c
	if [ ! -d $GOPATH/open-local ]; then
		curl https://raw.githubusercontent.com/helm/helm/master/scripts/get-helm-3 | bash
		git clone https://github.com/Zhuchengyu04/open-local.git "$GOPATH/open-local"
		cd $GOPATH/open-local
		helm install open-local $GOPATH/open-local/helm
	fi
	for IMAGE in ${EXAMPLE_IMAGE_LISTS[@]}; do
		pod_config="${FIXTURES_DIR}/sts-lvm.yaml"
		checkout_pod_yaml $pod_config $IMAGE
		eval $(parse_yaml $pod_config "_")
		POD_NAME=${_metadata_name}
		create_test_pod $pod_config
		if ! kubernetes_wait_cc_pod_be_ready "${POD_NAME}-0"; then
			kubectl delete -f ${FIXTURES_DIR}/sts-lvm.yaml
			kubectl delete pvc "html-${POD_NAME}-0"
			helm delete open-local
			rm -r $GOPATH/open-local
			return 1
		fi
		checkout_snapshot_yaml ${FIXTURES_DIR}/snapshot.yaml $IMAGE
		kubectl apply -f ${FIXTURES_DIR}/snapshot.yaml

		if  ! kubernetes_wait_cc_snapshot_be_ready ; then
			kubectl delete -f ${FIXTURES_DIR}/snapshot.yaml
			kubectl delete -f ${FIXTURES_DIR}/sts-lvm.yaml
			kubectl delete pvc "html-${POD_NAME}-0"
			helm delete open-local
			rm -r $GOPATH/open-local
			return 1
		fi
		checkout_pod_yaml "${FIXTURES_DIR}/sts-lvm-snap.yaml" $IMAGE
		kubectl apply -f ${FIXTURES_DIR}/sts-lvm-snap.yaml
		eval $(parse_yaml ${FIXTURES_DIR}/sts-lvm-snap.yaml "snap_")
		SNAP_POD_NAME=${snap_metadata_name}

		if ! kubernetes_wait_cc_pod_be_ready "${SNAP_POD_NAME}-0"; then
			kubernetes_delete_cc_pod_if_exists "${SNAP_POD_NAME}-0" || true
			kubectl delete -f ${FIXTURES_DIR}/sts-lvm-snap.yaml
			kubectl delete pvc "html-${SNAP_POD_NAME}-0"
			kubectl delete -f ${FIXTURES_DIR}/snapshot.yaml
			kubectl delete -f ${FIXTURES_DIR}/sts-lvm.yaml
			kubectl delete pvc "html-${POD_NAME}-0"
			helm delete open-local
			rm -r $GOPATH/open-local
			return 1
		fi
		kubernetes_delete_cc_pod_if_exists "${SNAP_POD_NAME}-0" || true
		kubectl delete -f ${FIXTURES_DIR}/sts-lvm-snap.yaml
		kubectl delete pvc "html-${SNAP_POD_NAME}-0"
		kubectl delete -f ${FIXTURES_DIR}/snapshot.yaml
		kubectl delete -f ${FIXTURES_DIR}/sts-lvm.yaml
		kubectl delete pvc "html-${POD_NAME}-0"

	done

	helm delete open-local
	rm -r $GOPATH/open-local
}
@test "Test signed image" {
	for IMAGE in ${EXAMPLE_IMAGE_LISTS[@]}; do
		skopeo --insecure-policy copy --sign-passphrase-file ${FIXTURES_DIR}/../signed/passwd.txt --sign-by $GPG_EMAIL docker://zcy-Z390-AORUS-MASTER.sh.intel.com/$IMAGE:latest docker://zcy-Z390-AORUS-MASTER.sh.intel.com/$IMAGE:signed
		tar -cf ${FIXTURES_DIR}/../signed/signatures.tar.gz /var/lib/containers/sigstore/$IMAGE*
		setup_skopeo_signature_files_in_guest
		checkout_pod_yaml "${FIXTURES_DIR}/pod-config.yaml" $IMAGE
		pod_config="${FIXTURES_DIR}/pod-config.yaml"
		create_test_pod $pod_config
		kubectl get pods
		eval $(parse_yaml $pod_config "_")
		kubernetes_delete_cc_pod_if_exists $_metadata_name || true
	done
}
@test "Test encrypted image" {

	generate_encrypted_image
	VERDICTDID=$(ps ux | grep "verdictd" | grep -v "grep" | awk '{print $2}')
	if [ "$VERDICTDID" == "" ]; then
		verdictd --listen 0.0.0.0:50000 --mutual >/dev/null 2>&1 &
	fi
	sleep 1
	setup_decryption_files_in_guest
	# ${FIXTURES_DIR}/../losetup-crt.sh $ROOTFS_IMAGE_PATH c
	for IMAGE in ${EXAMPLE_IMAGE_LISTS[@]}; do
		checkout_pod_yaml "${FIXTURES_DIR}/k8s-cc-ssh.yaml" $IMAGE
		pull_encrypted_image_inside_guest_with_decryption_key $IMAGE

	done
	VERDICTDID=$(ps ux | grep "verdictd " | grep -v "grep" | awk '{print $2}')
	echo $VERDICTDID
	sudo kill -9 $VERDICTDID
}

@test "Test uninstall operator" {
	reset_runtime
}

teardown() {

	restore
	reset_runtime
	# gpg --delete-keys $GPG_EMAIL
	# gpg --delete-secret-keys $GPG_EMAIL
	REGISTRY_CONTAINER=$(docker ps -a | grep "registry" | awk '{print $1}')
	if [ -n "$REGISTRY_CONTAINER" ]; then
		docker stop $REGISTRY_CONTAINER
		docker rm $REGISTRY_CONTAINER
	fi

}
