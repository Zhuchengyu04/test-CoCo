#!/usr/bin/env bats

load ./run/lib.sh
load ./run/cc_deploy.sh

test_tag="[cc][agent][kubernetes][containerd]"

setup() {
	start_date=$(date +"%Y-%m-%d %H:%M:%S")

}
# Create a pod configuration out of a template file.
#
# Parameters:
#	$1 - the container image.
# Return:
# 	the path to the configuration file. The caller should not care about
# 	its removal afterwards as it is created under the bats temporary
# 	directory.
#
# Environment variables:
#	RUNTIMECLASS: set the runtimeClassName value from $RUNTIMECLASS.
#
new_pod_config() {
	local base_config="$1"
	local image="$2"
	local runtimeclass="$3"
	local registryimage="$4"

	local new_config=$(mktemp "$TEST_COCO_PATH/../fixtures/$(basename ${base_config}).XXX")
	IMAGE="$image" RUNTIMECLASS="$runtimeclass" REGISTRTYIMAGE="$registryimage" envsubst <"$base_config" >"$new_config"
	echo "$new_config"
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
@test "Test unencrypted unsigned image" {
	for IMAGE in ${EXAMPLE_IMAGE_LISTS[@]}; do
		pod_config="$(new_pod_config $TEST_COCO_PATH/../fixtures/unsigned-unprotected-pod-config.yaml.in "$IMAGE" "$RUNTIMECLASS" "$REGISTRY_NAME/$IMAGE:$VERSION")"

		unencrypted_signed_image_from_unprotected_registry $pod_config
		rm $pod_config
	done
}
@test "Test trust storage" {
	# $TEST_COCO_PATH/../run/losetup-crt.sh $ROOTFS_IMAGE_PATH c
	if [ ! -d $GOPATH/open-local ]; then
		curl https://raw.githubusercontent.com/helm/helm/master/scripts/get-helm-3 | bash
		git clone https://github.com/Zhuchengyu04/open-local.git "$GOPATH/open-local"
		cd $GOPATH/open-local
		helm install open-local $GOPATH/open-local/helm
	fi
	for IMAGE in ${EXAMPLE_IMAGE_LISTS[@]}; do
		pod_config="$(new_pod_config $TEST_COCO_PATH/../fixtures/sts-lvm.yaml.in "$IMAGE" "$RUNTIMECLASS" "$REGISTRY_NAME/$IMAGE:$VERSION")"

		create_test_pod $pod_config
		POD_NAME=$(kubectl get pods -o jsonpath='{.items..metadata.name}')
		if ! kubernetes_wait_cc_pod_be_ready "${POD_NAME}"; then
			kubectl delete -f $pod_config
			kubectl delete pvc "html-${POD_NAME}"
			rm $pod_config
			helm delete open-local
			rm -r $GOPATH/open-local
			return 1
		fi
		checkout_snapshot_yaml $TEST_COCO_PATH/../fixtures/snapshot.yaml $IMAGE
		kubectl apply -f $TEST_COCO_PATH/../fixtures/snapshot.yaml

		if ! kubernetes_wait_cc_snapshot_be_ready; then
			kubectl delete -f $TEST_COCO_PATH/../fixtures/snapshot.yaml
			kubectl delete -f $pod_config
			kubectl delete pvc "html-${POD_NAME}"
			rm $pod_config
			helm delete open-local
			rm -r $GOPATH/open-local
			return 1
		fi
		pod_config_snap="$(new_pod_config $TEST_COCO_PATH/../fixtures/sts-lvm-snap.yaml.in "$IMAGE" "$RUNTIMECLASS" "$REGISTRY_NAME/$IMAGE:$VERSION")"

		kubectl apply -f $pod_config_snap
		eval $(parse_yaml $pod_config_snap "snap_")
		SNAP_POD_NAME=${snap_metadata_name}

		if ! kubernetes_wait_cc_pod_be_ready "${SNAP_POD_NAME}-0"; then
			kubernetes_delete_cc_pod_if_exists "${SNAP_POD_NAME}-0" || true
			kubectl delete -f $pod_config_snap
			kubectl delete pvc "html-${SNAP_POD_NAME}-0"
			rm $pod_config
			kubectl delete -f $TEST_COCO_PATH/../fixtures/snapshot.yaml
			kubectl delete -f $pod_config
			kubectl delete pvc "html-${POD_NAME}"
			rm $pod_config_snap
			helm delete open-local
			rm -r $GOPATH/open-local
			return 1
		fi
		kubernetes_delete_cc_pod_if_exists "${SNAP_POD_NAME}-0" || true
		kubectl delete -f $pod_config_snap
		kubectl delete pvc "html-${SNAP_POD_NAME}-0"
		rm $pod_config
		kubectl delete -f $TEST_COCO_PATH/../fixtures/snapshot.yaml
		kubectl delete -f $pod_config
		kubectl delete pvc "html-${POD_NAME}"
		rm $pod_config_snap
	done

	helm delete open-local
	rm -r $GOPATH/open-local
}
@test "Test signed image" {
	for IMAGE in ${EXAMPLE_IMAGE_LISTS[@]}; do
		skopeo --insecure-policy copy --sign-passphrase-file $TEST_COCO_PATH/../signed/passwd.txt --sign-by $GPG_EMAIL docker://zcy-Z390-AORUS-MASTER.sh.intel.com/$IMAGE:latest docker://zcy-Z390-AORUS-MASTER.sh.intel.com/$IMAGE:signed
		tar -cf ${TEST_COCO_PATH}/../signed/signatures.tar.gz /var/lib/containers/sigstore/$IMAGE*
		setup_skopeo_signature_files_in_guest
		pod_config="$(new_pod_config $TEST_COCO_PATH/../fixtures/pod-config.yaml.in "$IMAGE" "$RUNTIMECLASS" "$REGISTRY_NAME/$IMAGE:signed")"
		create_test_pod $pod_config
		kubectl get pods
		pod_id=$(kubectl get pods -o jsonpath='{.items..metadata.name}')
		kubernetes_delete_cc_pod_if_exists $pod_id || true
		rm $pod_config
	done
}
@test "Test encrypted image" {
	skip  "need to rebuild rootfs including eaa_bkc and guest kernel to test encrypted image, which is not supported in branch main of operator"
	generate_encrypted_image
	VERDICTDID=$(ps ux | grep "verdictd" | grep -v "grep" | awk '{print $2}')
	if [ "$VERDICTDID" == "" ]; then
		verdictd --listen 0.0.0.0:50000 --mutual >/dev/null 2>&1 &
	fi
	sleep 1
	setup_decryption_files_in_guest
	# $TEST_COCO_PATH/../run/losetup-crt.sh $ROOTFS_IMAGE_PATH c
	for IMAGE in ${EXAMPLE_IMAGE_LISTS[@]}; do
		pod_config="$(new_pod_config $TEST_COCO_PATH/../fixtures/k8s-cc-ssh.yaml.in "$IMAGE" "$RUNTIMECLASS" "$REGISTRY_NAME/$IMAGE:$VERSION")"

		pull_encrypted_image_inside_guest_with_decryption_key $pod_config
		rm $pod_config
	done
	VERDICTDID=$(ps ux | grep "verdictd " | grep -v "grep" | awk '{print $2}')
	echo $VERDICTDID
	kill -9 $VERDICTDID
}
@test "Test attestation" {
	skip  "TODO"
}
@test "Test measured boot" {
	skip  "TODO"
}
@test "Test multiple registries" {
	skip  "TODO"
}
@test "Test image sharing" {
	skip  "TODO"
}
@test "Test OnDemand image pulling" {
	skip  "TODO"
}
@test "Test TD preserving" {
	skip  "TODO"
}
@test "Test common cloud native projects" {
	skip  "TODO"
}

@test "Test uninstall operator" {
	reset_runtime
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
