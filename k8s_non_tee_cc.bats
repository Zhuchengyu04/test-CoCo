#!/usr/bin/env bats

load ./lib.sh


test_tag="[cc][agent][kubernetes][containerd]"
original_kernel_params=$(get_kernel_params)










setup() {
	start_date=$(date +"%Y-%m-%d %H:%M:%S")
	./cc_deploy.sh 
	echo "Prepare containerd for Confidential Container"
	# SAVED_CONTAINERD_CONF_FILE="/etc/containerd/config.toml.$$"
	# configure_cc_containerd "$SAVED_CONTAINERD_CONF_FILE"
	read_config
	echo "Reconfigure Kata Containers"
	switch_image_service_offload on
	clear_kernel_params
	add_kernel_params "${original_kernel_params}"
	add_kernel_params \
		"agent.container_policy_file=/etc/containers/quay_verification/quay_policy.json"
	rm /etc/systemd/system/containerd.service.d/containerd-for-cc-override.conf
	systemctl daemon-reload
	systemctl restart containerd
	# In case the tests run behind a firewall where images needed to be fetched
	# through a proxy.
	# local https_proxy="${HTTPS_PROXY:-${https_proxy:-}}"
	# if [ -n "$https_proxy" ]; then
	# 	echo "Enable agent https proxy"
	# 	add_kernel_params "agent.https_proxy=$https_proxy"

	# 	local local_dns=$(grep nameserver /etc/resolv.conf \
	# 		/run/systemd/resolve/resolv.conf 2>/dev/null |
	# 		grep -v "127.0.0.53" | cut -d " " -f 2 | head -n 1)
	# 	local new_file="${BATS_FILE_TMPDIR}/$(basename ${pod_config})"
	# 	echo "New pod configuration with local dns: $new_file"
	# 	cp -f "${pod_config}" "${new_file}"
	# 	pod_config="$new_file"
	# 	sed -i -e 's/8.8.8.8/'${local_dns}'/' "${pod_config}"
	# 	cat "$pod_config"
	# fi
	run_registry
	create_image_size
}




@test "$test_tag Test unencrypted unsigned image" {

	setup
	

	for IMAGE in ${IMAGE_LISTS[@]}; do
		checkout_pod_yaml "./fixtures/unsigned-unprotected-pod-config.yaml" $IMAGE
		unencrypted_signed_image_from_unprotected_registry $IMAGE

	done
	teardown
}
@test "$test_tag Test encrypted image" {
	setup
	generate_encrypted_image
	VERDICTDID=$(ps ux | grep "verdictd" | grep -v "grep" | awk '{print $2}')
	if [ "$VERDICTDID" == "" ]; then
		verdictd --listen 0.0.0.0:50000 --mutual >/dev/null 2>&1 &
	fi
	sleep 1
	setup_decryption_files_in_guest
	for IMAGE in ${IMAGE_LISTS[@]}; do
		checkout_pod_yaml "${FIXTURES_DIR}/k8s-cc-ssh.yaml" $IMAGE
		pull_encrypted_image_inside_guest_with_decryption_key $IMAGE

	done
	VERDICTDID=$(ps ux | grep "verdictd " | grep -v "grep" | awk '{print $2}')
	echo $VERDICTDID
	sudo kill -9 $VERDICTDID
	teardown
}

@test "$test_tag Test signed image" {
	setup
	for IMAGE in ${IMAGE_LISTS[@]}; do
		skopeo --insecure-policy copy --sign-passphrase-file ${FIXTURES_DIR}/../signed/passwd.txt --sign-by intel@intel.com docker-daemon:registry:2 docker://zcy-Z390-AORUS-MASTER.sh.intel.com/$IMAGE:latest
		tar -cf ${FIXTURES_DIR}/../signed/signatures.tar.gz /var/lib/containers/sigstore/$IMAGE*
		setup_skopeo_signature_files_in_guest
		checkout_pod_yaml "${FIXTURES_DIR}/pod-config.yaml" $IMAGE
		pod_config="${FIXTURES_DIR}/pod-config.yaml"
		create_test_pod $pod_config
		kubectl get pods
		eval $(parse_yaml $pod_config "_")
		kubernetes_delete_cc_pod_if_exists $_metadata_name || true
		# exit 0
	done
	teardown
}
@test "$test_tag Test trust storage" {
	setup
	${FIXTURES_DIR}/../losetup-crt.sh $ROOTFS_IMAGE_PATH c
	git clone https://github.com/Zhuchengyu04/open-local.git "$TEST_DIR/open-local"
	cd $TEST_DIR/open-local

	helm install open-local ./helm

	pod_config="${FIXTURES_DIR}/sts-nginx.yaml"
	eval $(parse_yaml $pod_config "_")

	create_test_pod $pod_config
	if ! kubernetes_wait_cc_pod_be_ready "${_metadata_name}-0"; then
		return 1
	fi
	kubectl apply -f ${FIXTURES_DIR}/snapshot.yaml
	kubectl get volumesnapshot
	kubectl wait --timeout=10s --for=jsonpath={.status.readyToUse}=true volumesnapshot/new-snapshot-test

	kubectl apply -f ${FIXTURES_DIR}/sts-nginx-snap.yaml
	if ! kubernetes_wait_cc_pod_be_ready "example-lvm-snap-0"; then
		return 1
	fi
	kubernetes_delete_cc_pod_if_exists "example-lvm-snap-0" || true
	kubectl delete -f ${FIXTURES_DIR}/sts-nginx-snap.yaml

	kubectl delete -f ${FIXTURES_DIR}/snapshot.yaml
	kubectl delete -f ${FIXTURES_DIR}/sts-nginx.yaml

	helm delete open-local
	teardown
}

teardown() {

	restore
	REGISTRY_CONTAINER=$(docker ps -a | grep "registry" | awk '{print $1}')
    if [ -n "$REGISTRY_CONTAINER" ]; then
        docker stop $REGISTRY_CONTAINER
        docker rm $REGISTRY_CONTAINER
    fi

}
