#!/usr/bin/env bash

set -e
source run/common.bash

parse_yaml() {
    local prefix=$2
    local s='[[:space:]]*' w='[a-zA-Z0-9_]*' fs=$(echo @ | tr @ '\034')
    sed -ne "s|^\($s\):|\1|" \
        -e "s|^\($s\)\($w\)$s:$s[\"']\(.*\)[\"']$s\$|\1$fs\2$fs\3|p" \
        -e "s|^\($s\)\($w\)$s:$s\(.*\)$s\$|\1$fs\2$fs\3|p" $1 |
        awk -F$fs '{
      indent = length($1)/2;
      vname[indent] = $2;
      for (i in vname) {if (i > indent) {delete vname[i]}}
      if (length($3) > 0) {
         vn=""; for (i=0; i<indent; i++) {vn=(vn)(vname[i])("_")}
         printf("%s%s%s=\"%s\"\n", "'$prefix'",vn, $2, $3);
      }
   }'
}
# Toggle between true and false the service_offload configuration of
# the Kata agent.
#
# Parameters:
#	$1: "on" to activate the service, or "off" to turn it off.
#
# Environment variables:
#	RUNTIME_CONFIG_PATH - path to kata's configuration.toml. If it is not
#			      export then it will figure out the path via
#			      `kata-runtime env` and export its value.
#

extract_kata_env() {
    # RUNTIME_CONFIG_PATH=$(kata-runtime kata-env --json | jq -r .Runtime.Config.Path)
    RUNTIME_VERSION=$(kata-runtime kata-env --json | jq -r .Runtime.Version | grep Semver | cut -d'"' -f4)
    RUNTIME_COMMIT=$(kata-runtime kata-env --json | jq -r .Runtime.Version | grep Commit | cut -d'"' -f4)
    RUNTIME_PATH=$(kata-runtime kata-env --json | jq -r .Runtime.Path)

    # Shimv2 path is being affected by https://github.com/kata-containers/kata-containers/issues/1151
    SHIM_PATH=$(command -v containerd-shim-kata-v2)
    SHIM_VERSION=${RUNTIME_VERSION}

    HYPERVISOR_PATH=$(kata-runtime kata-env --json | jq -r .Hypervisor.Path)
    # TODO: there is no kata-runtime of rust version currently
    if [ "${KATA_HYPERVISOR}" != "dragonball" ]; then
        HYPERVISOR_VERSION=$(${HYPERVISOR_PATH} --version | head -n1)
    fi
    VIRTIOFSD_PATH=$(kata-runtime kata-env --json | jq -r .Hypervisor.VirtioFSDaemon)

}
#
# Auxiliar functions.
#

# Export the RUNTIME_CONFIG_PATH variable if it not set already.
#
load_runtime_config_path() {
    extract_kata_env
}
# Add parameters to the 'kernel_params' property on kata's configuration.toml
#
# Parameters:
#	$1..$N - list of parameters
#
# Environment variables:
#	CURRENT_CONFIG_FILES - path to kata's configuration.toml. If it is not
#			      export then it will figure out the path via
#			      `kata-runtime env` and export its value.
#
add_kernel_params() {
    local params="$@"

    sudo sed -i -e 's#^\(kernel_params\) = "\(.*\)"#\1 = "\2 '"$params"'"#g' \
        "$RUNTIME_CONFIG_PATH/$CURRENT_CONFIG_FILES"
}
# Get the 'kernel_params' property on kata's configuration.toml
#
# Environment variables:
#	CURRENT_CONFIG_FILES - path to kata's configuration.toml. If it is not
#			      export then it will figure out the path via
#			      `kata-runtime env` and export its value.
#
get_kernel_params() {
    load_runtime_config_path
    echo ${RUNTIME_PATH}
    local kernel_params=$(sed -n -e 's#^kernel_params = "\(.*\)"#\1#gp' \
        "$RUNTIME_CONFIG_PATH/$CURRENT_CONFIG_FILES")
    echo "${kernel_params}"
}
# Configure containerd for confidential containers. Among other things, it ensures
# the CRI handler is configured to deal with confidential container.
#
# Parameters:
#	$1 - (Optional) file path to where save the current containerd's config.toml
#
configure_cc_containerd() {
    local saved_containerd_conf_file="${1:-}"
    local containerd_conf_file="/etc/containerd/config.toml"

    # Even if we are not saving the original file it is a good idea to
    # restart containerd because it might be in an inconsistent state here.
    systemctl stop containerd
    sleep 5
    [ -n "$saved_containerd_conf_file" ] &&
        cp -f "$containerd_conf_file" "$saved_containerd_conf_file"
    systemctl start containerd

    # waitForProcess 30 5 " crictl info >/dev/null"
    sleep 5
    # Ensure the cc CRI handler is set.
    # local cri_handler=$(crictl info |
    # 	jq '.config.containerd.runtimes.kata.cri_handler')
    # if [[ ! "$cri_handler" =~ cc ]]; then
    # 	sed -i 's/\([[:blank:]]*\)\(runtime_type = "io.containerd.kata.v2"\)/\1\2\n\1cri_handler = "cc"/' \
    # 		"$containerd_conf_file"
    # fi

    if [ "$(crictl info | jq -r '.config.cni.confDir')" = "null" ]; then
        echo "    [plugins.cri.cni]
		  # conf_dir is the directory in which the admin places a CNI conf.
		  conf_dir = \"/etc/cni/net.d\"" |
            tee -a "$containerd_conf_file"
    fi

    systemctl restart containerd
    sleep 5

    # if ! waitForProcess 30 5 " crictl info >/dev/null"; then
    # 	die "containerd seems not operational after reconfigured"
    # fi
    iptables -P FORWARD ACCEPT
}
waitForProcess() {
    wait_time="$1"
    sleep_time="$2"
    cmd="$3"
    while [ "$wait_time" -gt 0 ]; do
        if eval "$cmd"; then
            return 0
        else
            sleep "$sleep_time"
            wait_time=$((wait_time - sleep_time))
        fi
    done
    return 1
}
switch_image_service_offload() {
    # Load the CURRENT_CONFIG_FILES variable.
    load_runtime_config_path

    case "$1" in
    "on")
        sudo sed -i -e 's/^\(service_offload\).*=.*$/\1 = true/g' \
            "$RUNTIME_CONFIG_PATH/$CURRENT_CONFIG_FILES"
        ;;
    "off")
        sudo sed -i -e 's/^\(service_offload\).*=.*$/\1 = false/g' \
            "$RUNTIME_CONFIG_PATH/$CURRENT_CONFIG_FILES"

        ;;
    *)
        die "Unknown option '$1'"
        ;;
    esac
}
# Clear the 'kernel_params' property on kata's configuration.toml
#
# Environment variables:
#	CURRENT_CONFIG_FILES - path to kata's configuration.toml. If it is not
#			      export then it will figure out the path via
#			      `kata-runtime env` and export its value.
#
clear_kernel_params() {

    sed -i -e 's#^\(kernel_params\) = "\(.*\)"#\1 = ""#g' \
        "$RUNTIME_CONFIG_PATH/$CURRENT_CONFIG_FILES"
}
# Wait until the pod is not 'Ready'. Fail if it hits the timeout.
#
# Parameters:
#	$1 - the sandbox ID
#	$2 - wait time in seconds. Defaults to 60. (optional)
#
kubernetes_wait_cc_pod_be_ready() {
    local pod_name="$1"
    local wait_time="${2:-120}"

    kubectl wait --timeout=${wait_time}s --for=condition=ready pods/$pod_name
}
kubernetes_wait_cc_pod_be_running() {
    local pod_name="$1"
    local wait_time="${2:-15}"

    kubectl wait --timeout=${wait_time}s --for=jsonpath='{.status.phase}'=Running pods/$pod_name
}
kubernetes_wait_cc_snapshot_be_ready() {
    local pod_name="$1"
    local wait_time="${2:-120}"

    kubectl wait --timeout=${wait_time}s --for=jsonpath='{.status.readyToUse}'=true volumesnapshot/new-snapshot-test
}
# Create a pod and wait it be ready, otherwise fail.
#
# Parameters:
#	$1 - the pod configuration file.
#
kubernetes_create_cc_pod() {
    local config_file="$1"
    local pod_name=""

    if [ ! -f "${config_file}" ]; then
        echo "Pod config file '${config_file}' does not exist"
        return 1
    fi

    kubectl apply -f ${config_file}
    if ! pod_name=$(kubectl get pods -o jsonpath='{.items..metadata.name}'); then
        echo "Failed to create the pod"
        return 1
    fi

    if ! kubernetes_wait_cc_pod_be_ready "$pod_name"; then
        # TODO: run this command for debugging. Maybe it should be
        #       guarded by DEBUG=true?
        kubectl get pods "$pod_name"
        return 1
    fi
}
enable_agent_console() {
    load_runtime_config_path

    sudo sed -i -e 's/^# *\(debug_console_enabled\).*=.*$/\1 = true/g' \
        "$RUNTIME_CONFIG_PATH/$CURRENT_CONFIG_FILES"
}

enable_full_debug() {
    # Load the RUNTIME_CONFIG_PATH variable.
    load_runtime_config_path

    # Toggle all the debug flags on in kata's configuration.toml to enable full logging.
    sed -i -e 's/^# *\(enable_debug\).*=.*$/\1 = true/g' "$RUNTIME_CONFIG_PATH/$CURRENT_CONFIG_FILES"

    # Also pass the initcall debug flags via Kernel parameters.
    # add_kernel_params "agent.log=debug" "initcall_debug"
}
# Create the test pod.
#
# Note: the global $sandbox_name, $pod_config should be set
# 	already. It also relies on $CI and $DEBUG exported by CI scripts or
# 	the developer, to decide how to set debug flags.
#
create_test_pod() {
    # On CI mode we only want to enable the agent debug for the case of
    # the test failure to obtain logs.
    if [ "${CI:-}" == "true" ]; then
        enable_full_debug
    elif [ "${DEBUG:-}" == "true" ]; then
        enable_full_debug
        enable_agent_console
    fi

    echo "Create the test sandbox"
    echo "Pod config is: "$1
    kubernetes_create_cc_pod $1
}
# Delete the containers alongside the Pod.
#
# Parameters:
#	$1 - the sandbox name
#
kubernetes_delete_cc_pod() {
    local sandbox_name="$1"
    local pod_id=${sandbox_name}
    if [ -n "${pod_id}" ]; then

        kubectl delete pod "${pod_id}"
    fi
}

# Delete the pod if it exists, otherwise just return.
#
# Parameters:
#	$1 - the sandbox name
#
kubernetes_delete_cc_pod_if_exists() {
    local sandbox_name="$1"
    [ -z "$(kubectl get pods ${sandbox_name})" ] ||
        kubernetes_delete_cc_pod "${sandbox_name}"
}
# Check the logged messages on host have a given message.
# Parameters:
#      $1 - the message
#
# Note: get the logs since the global $start_date.
#
assert_logs_contain() {
    local message="$1"
    journalctl -x -t kata --since "$start_date" | grep "$message"
}
checkout_pod_yaml() {
    pod_config=$1
    current_image_name=$2
    eval $(parse_yaml $pod_config "_")
    image_name=$(echo $_metadata_name | cut -d '-' -f 1)
    echo "--------------"
    echo ${image_name,,}
    echo ${current_image_name,,}
    echo "--------------"
    sed -i "s/${image_name,,}/${current_image_name,,}/g" $pod_config
    # exit 0
}
checkout_snapshot_yaml() {
    pod_config=$1
    current_image_name=$2
    eval $(parse_yaml $pod_config "snapshot_")
    image_name=$(echo $snapshot_spec_source_persistentVolumeClaimName | cut -d '-' -f 2)
    echo ${image_name}
    sed -i "s/${image_name,,}/${current_image_name,,}/g" $pod_config

}
# Copy local files to the guest image.
#
# Parameters:
#	$1      - destination directory in the image. It is created if not exist.
#	$2..*   - list of local files.
#
cp_to_guest_img() {
    local dest_dir="$1"
    # local image_path="$2"
    shift # remaining arguments are the list of files.
    local src_files=($@)
    local rootfs_dir=""

    if [ "${#src_files[@]}" -eq 0 ]; then
        echo "Expected a list of files"
        return 1
    fi

    rootfs_dir="$(mktemp -d)"
    local image_path=$ROOTFS_IMAGE_PATH

    # Open the original initrd/image, inject the agent file
    # local image_path="$(sudo -E PATH=$PATH kata-runtime kata-env --json | jq -r .Image.Path)"

    if [ -f "$image_path" ]; then
        if ! sudo mount -o loop,offset=$((512 * 6144)) "$image_path" \
            "$rootfs_dir"; then
            echo "Failed to mount the image file: $image_path"
            rm -rf "$rootfs_dir"
            return 1
        fi
    else
        local initrd_path="$(sudo -E PATH=$PATH kata-runtime kata-env --json |
            jq -r .Initrd.Path)"
        if [ ! -f "$initrd_path" ]; then
            echo "Guest initrd and image not found"
            rm -rf "$rootfs_dir"
            return 1
        fi

        if ! cat "${initrd_path}" | cpio --extract --preserve-modification-time \
            --make-directories --directory="${rootfs_dir}"; then
            echo "Failed to uncompress the image file: $initrd_path"
            rm -rf "$rootfs_dir"
            return 1
        fi
    fi
    sudo mkdir -p "${rootfs_dir}/${dest_dir}"

    for file in ${src_files[@]}; do
        if [ ! -f "$file" ] && [ ! -d "$file" ]; then
            echo "File not found, not copying: $file"
            continue
        fi

        if [ -f "$file" ]; then
            sudo cp -af "${file}" "${rootfs_dir}/${dest_dir}"
        else
            sudo cp -ad "${file}" "${rootfs_dir}/${dest_dir}"
        fi
    done
    # umount "$rootfs_dir"
    # rm -rf "$rootfs_dir"
    if [ -f "$image_path" ]; then
        if ! sudo umount "$rootfs_dir"; then
            echo "Failed to umount the directory: $rootfs_dir"
            rm -rf "$rootfs_dir"
            return 1
        fi
    else
        if ! sudo bash -c "cd "${rootfs_dir}" && find . | \
			cpio -H newc -o | gzip -9 > ${initrd_path}"; then
            echo "Failed to compress the image file"
            rm -rf "$rootfs_dir"
            return 1
        fi
    fi

    rm -rf "$rootfs_dir"
}
generate_encrypted_image() {
    # git clone https://github.com/containers/attestation-agent $GOPATH/src/github.com/attestation-agent
    # cd $GOPATH/src/github.com/attestation-agent
    # make KBC=eaa_kbc && make install

    # git clone -b 2022-poc https://github.com/jialez0/verdictd $GOPATH/src/github.com/verdictd
    # cd $GOPATH/src/github.com/verdictd
    # make
    # make install

    # git clone https://github.com/containers/skopeo $GOPATH/src/github.com/containers/skopeo
    # cd $GOPATH/src/github.com/containers/skopeo && make bin/skopeo
    # apt-get install go-md2man
    # make install

    # Generate the key provider configuration file
    if [ ! -d /etc/containerd/ocicrypt/ ]; then
        mkdir -p /etc/containerd/ocicrypt/
    fi
    cat <<-EOF >/etc/containerd/ocicrypt/ocicrypt_keyprovider.conf
{
        "key-providers": {
                "attestation-agent": {
                    "grpc": "127.0.0.1:50001"

                }
        }
}
EOF

    # Generate a encryption key
    if [ ! -d /opt/verdictd/keys/ ]; then
        mkdir -p /opt/verdictd/keys/
    fi
    cat <<-EOF >/opt/verdictd/keys/84688df7-2c0c-40fa-956b-29d8e74d16c0
1234567890123456789012345678901
EOF

    VERDICTDID=$(ps ux | grep "verdictd --client-api" | grep -v "grep" | awk '{print $2}')
    if [ "$VERDICTDID" == "" ]; then
        # verdictd --client-api 127.0.0.1:50001 >/dev/null 2>&1 &
        verdictd --client-api 127.0.0.1:50001 2>&1 &
    fi
    sleep 1
    # Launch Verdictd in another terminal

    # skopeo --insecure-policy copy docker://docker.io/library/busybox:latest oci:busybox
    # skopeo copy --insecure-policy --encryption-key provider:attestation-agent:84688df7-2c0c-40fa-956b-29d8e74d16c0 oci:busybox docker://zcy-Z390-AORUS-MASTER.sh.intel.com/busybox-encrypted:latest

    export OCICRYPT_KEYPROVIDER_CONFIG=/etc/containerd/ocicrypt/ocicrypt_keyprovider.conf

    for IMAGE in ${IMAGE_LISTS[@]}; do
        skopeo --insecure-policy copy docker://${REGISTRY_NAME}/${IMAGE}:latest oci:$STORAGE_FILE_D/${IMAGE}
        skopeo copy --insecure-policy --encryption-key provider:attestation-agent:84688df7-2c0c-40fa-956b-29d8e74d16c0 oci:$STORAGE_FILE_D/${IMAGE} docker://${REGISTRY_NAME}/${IMAGE}-encrypted:latest
        rm -r $STORAGE_FILE_D/${IMAGE}
    done

    # generate encrypted image

    VERDICTDID=$(ps ux | grep "verdictd --client-api" | grep -v "grep" | awk '{print $2}')
    echo $VERDICTDID
    sudo kill -9 $VERDICTDID
}
setup_offline_fs_kbc_agent_config_in_guest() {
    local rootfs_agent_config="/etc/agent-config.toml"

    # clone_katacontainers_repo
    sudo -E AA_KBC_PARAMS='eaa_kbc::10.239.159.53:50000' envsubst <confidential-agent-config.toml.in | sudo tee ${rootfs_agent_config}
    # sudo -E AA_KBC_PARAMS="eaa_kbc::127.0.0:50000" envsubst <${katacontainers_repo_dir}/docs/how-to/data/confidential-agent-config.toml.in | sudo tee ${rootfs_agent_config}

    # sudo -E AA_KBC_PARAMS="offline_fs_kbc::null" HTTPS_PROXY="${HTTPS_PROXY:-${https_proxy:-}}" envsubst < ${katacontainers_repo_dir}/docs/how-to/data/confidential-agent-config.toml.in | sudo tee ${rootfs_agent_config}

    # TODO #5173 - remove this once the kernel_params aren't ignored by the agent config
    # Enable debug log_level and debug_console access based on env vars
    echo "log_level = \"debug\"" | sudo tee -a "${rootfs_agent_config}"
    echo -e "debug_console = true\ndebug_console_vport = 1026" | sudo tee -a "${rootfs_agent_config}"
    echo -e "dev_mode = false\nserver_addr = \"vsock://-1:4096\"\nlog_vport = 0\ncontainer_pipe_size = 0\nunified_cgroup_hierarchy = false\ntracing = false" | sudo tee -a "${rootfs_agent_config}"
    # Uncomment the 'ExecProcessRequest' endpoint as our test currently uses exec to check the container
    sudo sed -i 's/#\("ExecProcessRequest"\)/\1/g' "${rootfs_agent_config}"
    cp_to_guest_img "/tests/fixtures" "${rootfs_agent_config}"
    add_kernel_params "agent.config_file=/tests/fixtures/$(basename ${rootfs_agent_config})"
    # add_kernel_params "agent.config_file=${rootfs_agent_config}"
    # cat "${rootfs_agent_config}"
}
setup_decryption_files_in_guest() {

    setup_offline_fs_kbc_agent_config_in_guest
}

kubernetes_create_ssh_demo_pod() {
    kubectl apply -f "$TEST_COCO_PATH/../fixtures/k8s-cc-ssh.yaml" && pod=$(kubectl get pods -o jsonpath='{.items..metadata.name}') && kubectl wait --timeout=60s --for=condition=ready pods/$pod

    kubectl get pod $pod
}
kubernetes_delete_ssh_demo_pod_if_exists() {
    local sandbox_name="$1"
    if [ -n "$(kubectl get pods $sandbox_name)" ]; then
        kubernetes_delete_ssh_demo_pod ${sandbox_name}
    fi
}

kubernetes_delete_ssh_demo_pod() {
    kubectl delete -f "$TEST_COCO_PATH/../fixtures/k8s-cc-ssh.yaml"

    kubectl wait pod/$1 --for=delete --timeout=-30s
}
generate_gpg_key() {
    gpg --expert --full-gen-key <<ESXU
1
4096
4096
0
y
$GPG_EMAIL
$GPG_EMAIL
$GPG_EMAIL
o
$GPG_EMAIL
$GPG_EMAIL

ESXU
}
setup_skopeo_signature_files_in_guest() {
    setup_common_signature_files_in_guest
    cp_to_guest_img "${rootfs_directory}" "/etc/containers/registries.d"
}

setup_common_signature_files_in_guest() {
    rootfs_directory="etc/containers/"
    signatures_dir="$TEST_COCO_PATH/../signed/signatures"

    if [ ! -d "${signatures_dir}" ]; then
        sudo mkdir "${signatures_dir}"
    fi

    sudo tar -xf "$TEST_COCO_PATH/../signed/signatures.tar.gz" -C "${signatures_dir}"

    cp_to_guest_img "${rootfs_directory}" "$TEST_COCO_PATH/../signed"
}
#"$test_tag Test can pull an unencrypted unsigned image from an unprotected registry"
unencrypted_signed_image_from_unprotected_registry() {
    pod_config="$TEST_COCO_PATH/../fixtures/unsigned-unprotected-pod-config.yaml"
    eval $(parse_yaml $pod_config "_")
    echo $_metadata_name
    create_test_pod $pod_config
    if ! kubernetes_wait_cc_pod_be_running "$_metadata_name"; then
        # TODO: run this command for debugging. Maybe it should be
        #       guarded by DEBUG=true?
        kubectl get pods "$_metadata_name"
        return 1
    fi
    kubectl get pods
    # read -p "wait a minute:" tests
    # eval $(parse_yaml $pod_config "_")
    kubernetes_delete_cc_pod_if_exists $_metadata_name || true

}

# @test "$test_tag Test can pull an encrypted image inside the guest with decryption key"
pull_encrypted_image_inside_guest_with_decryption_key() {

    kubernetes_create_ssh_demo_pod

    pod_id=$(kubectl get pods -o jsonpath='{.items..metadata.name}')
    kubernetes_delete_ssh_demo_pod_if_exists "$pod_id" || true
}
create_file_for_size() {
    local file_size=$1
    local file_unit=$2
    if [ ! -d "${STORAGE_FILE_D}" ]; then
        sudo mkdir "${STORAGE_FILE_D}"
    fi

    head -c $file_size${file_unit}B /dev/zero >${STORAGE_FILE_D}/file-$file_size$file_unit.txt

    docker run -dt alpine:latest
    DOCKERID=$(docker ps | grep alpine | awk '{print $1}')
    echo $DOCKERID
    docker cp ${STORAGE_FILE_D}/file-$file_size$file_unit.txt $DOCKERID:/tmp/
    docker commit $DOCKERID example$file_size${file_unit,,}
    docker stop $DOCKERID && docker rm $DOCKERID
    docker tag example$file_size${file_unit,,} $REGISTRY_NAME/example$file_size${file_unit,,}:$VERSION
    docker push $REGISTRY_NAME/example$file_size${file_unit,,}:$VERSION
}
create_image_size() {
    for IMAGE in ${IMAGE_LISTS[@]}; do
        UNIT=$(echo $IMAGE | sed 's/[^A-Z]//g')
        SIZES=$(echo $IMAGE | sed 's/[^0-9 ]//g')
        echo $UNIT
        echo $SIZES
        create_file_for_size $SIZES $UNIT
    done

}
#generate .crt and .key
generate_crt() {
    # openssl req -newkey rsa:4096 -nodes -sha256 -keyout ${CERTS_PATH}certs/domain.key -addext "subjectAltName = ${TYPE_NAME}:${REGISTRY_NAME}" -x509 -days 365 -out ${CERTS_PATH}certs/domain.crt
    openssl req -newkey rsa:4096 -nodes -sha256 -keyout $TEST_COCO_PATH/../certs/domain.key -addext "subjectAltName = ${TYPE_NAME}:${REGISTRY_NAME}" -x509 -days 365 -out $TEST_COCO_PATH/../certs/domain.crt <<ESXU
12

12

12

12

12
ESXU
}

run_registry() {
    # delete all docker containers and images
    REGISTRY_CONTAINER=$(docker ps -a | grep "registry" | awk '{print $1}')
    if [ -n "$REGISTRY_CONTAINER" ]; then
        docker stop $REGISTRY_CONTAINER
        docker rm $REGISTRY_CONTAINER
    fi
    generate_crt
    cp $TEST_COCO_PATH/../certs/domain.crt /usr/local/share/ca-certificates/${REGISTRY_NAME}.crt

    update-ca-certificates

    # Deploy docker registry
    docker run -d --restart=always --name $REGISTRY_NAME -v $TEST_COCO_PATH/../certs:/certs \
        -e REGISTRY_HTTP_ADDR=0.0.0.0:$PORT -e REGISTRY_HTTP_TLS_CERTIFICATE=/certs/domain.crt \
        -e REGISTRY_HTTP_TLS_KEY=/certs/domain.key -p $PORT:$PORT registry:2

    # docker run -d --restart=always --name zcy-Z390-AORUS-MASTER.sh.intel.com -v certs:/certs \
    #     -e REGISTRY_HTTP_ADDR=0.0.0.0:443 -e REGISTRY_HTTP_TLS_CERTIFICATE=/certs/domain.crt \
    #     -e REGISTRY_HTTP_TLS_KEY=/certs/domain.key -p 443:443 registry:2

    pull_image
    # create_image_size
}

pull_image() {
    VERSION=latest
    for IMAGE in ${EXAMPLE_IMAGE_LISTS[@]}; do
        docker pull $IMAGE:$VERSION
        docker tag $IMAGE:$VERSION $REGISTRY_NAME/$IMAGE:$VERSION
        docker push $REGISTRY_NAME/$IMAGE:$VERSION
    done
}

read_config() {
    export KUBECONFIG=/etc/kubernetes/admin.conf
    # export GOPATH="$(mktemp -d)"
    export GOPATH=/root/go
    # export GOPATH=$(go env | grep GOPATH | cut -d'=' -f2)
    export TEST_DIR="$GOPATH/src/github.com/tests"
    echo $TEST_COCO_PATH
    export RUNTIME_CONFIG_PATH=$(jq -r '.config.runtimeConfigPath' $TEST_COCO_PATH/../config/test_config.json)
    export FIXTURES_DIR=$(jq -r '.config.podConfigPath' $TEST_COCO_PATH/../config/test_config.json)
    export CONFIG_FILES=($(ls -l ${RUNTIME_CONFIG_PATH} | awk '{print $9}'))
    export CURRENT_CONFIG_FILES=${CONFIG_FILES[1]}
    export RUNTIMECLASS=$(jq -r '.config.runtimes' $TEST_COCO_PATH/../config/test_config.json)

    export katacontainers_repo_dir=$GOPATH/src/github.com/kata-containers/kata-containers
    export ROOTFS_IMAGE_PATH=$(jq -r '.file.rootfs' $TEST_COCO_PATH/../config/test_config.json)
    export CONTAINERD_CONF_FILE=$(jq -r '.file.containerd_file' $TEST_COCO_PATH/../config/test_config.json)
    export OPERATOR_VERSION=$(jq -r '.file.operator_version' $TEST_COCO_PATH/../config/test_config.json)

    export IMAGE_LISTS=$(jq -r .file.image_lists[] $TEST_COCO_PATH/../config/test_config.json)
    # export IMAGE_LISTS=(busybox redis mysql ruby rust swift)
    # export NORMAL_IMAGE_LISTS=$(jq -r .file.image_lists[] $TEST_COCO_PATH/../config/test_config.json)
    export EXAMPLE_IMAGE_LISTS=$(jq -r .file.comments_image_lists[] $TEST_COCO_PATH/../config/test_config.json)
    # export IMAGE_LISTS=(${NORMAL_IMAGE_LISTS[@]} ${EXAMPLE_IMAGE_LISTS[@]})
    export VERSION=latest
    # export CERTS_PATH=$(jq -r '.certificates.certsPath' $TEST_COCO_PATH/../config/test_config.json)
    export TYPE_NAME=$(jq -r '.certificates.type' $TEST_COCO_PATH/../config/test_config.json)
    export REGISTRY_NAME=$(jq -r '.certificates.registry' $TEST_COCO_PATH/../config/test_config.json)
    export PORT=$(jq -r '.certificates.port' $TEST_COCO_PATH/../config/test_config.json)
    export STORAGE_FILE_D=$(jq -r '.certificates.image_path' $TEST_COCO_PATH/../config/test_config.json)
    export REGISTRY_IP=$(jq -r '.certificates.ip' $TEST_COCO_PATH/../config/test_config.json)
    export GPG_EMAIL=$(jq -r '.certificates.gpg_email' $TEST_COCO_PATH/../config/test_config.json)

    if [ ! -d $katacontainers_repo_dir ]; then
        git clone -b CCv0 https://github.com/kata-containers/kata-containers $katacontainers_repo_dir
    fi
}

backup() {
    # export BACKUP_PATH="$(mktemp -d)"
    export BACKUP_PATH="/root/shells/kata/backup"
    echo $BACKUP_PATH
    if [ ! -d $BACKUP_PATH$RUNTIME_CONFIG_PATH ]; then
        mkdir -p $BACKUP_PATH$RUNTIME_CONFIG_PATH
    fi
    cp -r $RUNTIME_CONFIG_PATH $BACKUP_PATH$RUNTIME_CONFIG_PATH
    if [ ! -d $BACKUP_PATH$FIXTURES_DIR ]; then

        mkdir -p $BACKUP_PATH$FIXTURES_DIR
    fi
    cp -r $FIXTURES_DIR $BACKUP_PATH$FIXTURES_DIR
    if [ ! -d $BACKUP_PATH$(dirname ${ROOTFS_IMAGE_PATH}) ]; then

        mkdir -p $BACKUP_PATH$(dirname ${ROOTFS_IMAGE_PATH})
    fi
    cp $ROOTFS_IMAGE_PATH $BACKUP_PATH$ROOTFS_IMAGE_PATH
    if [ ! -d $BACKUP_PATH$(dirname ${CONTAINERD_CONF_FILE}) ]; then
        mkdir -p $BACKUP_PATH$(dirname ${CONTAINERD_CONF_FILE})
    fi
    cp $CONTAINERD_CONF_FILE $BACKUP_PATH$CONTAINERD_CONF_FILE
    if [ ! -d $TEST_DIR ]; then
        mkdir -p $TEST_DIR
    fi

}

restore() {
    # cp -r $BACKUP_PATH$RUNTIME_CONFIG_PATH ${RUNTIME_CONFIG_PATH}
    # cp -r $BACKUP_PATH$FIXTURES_DIR ${FIXTURES_DIR}
    # cp $BACKUP_PATH$ROOTFS_IMAGE_PATH ${ROOTFS_IMAGE_PATH}
    # cp $BACKUP_PATH$CONTAINERD_CONF_FILE ${CONTAINERD_CONF_FILE}
    rm -r $katacontainers_repo_dir
    # rm -r $GOPATH
}
check_cc_runtime() {
    RUNTIMELISTS=("kata" "kata-clh" "kata-clh-tdx" "kata-qemu" "kata-qemu-sev" "kata-qemu-tdx")
    COUNT=0
    for RUNTIME in ${RUNTIMELISTS[@]}; do
        RUNTIMES=$(kubectl get runtimeclass -ojson | jq -r .items[$COUNT].metadata.name)
        if [ "$RUNTIMES" != "$RUNTIME" ]; then
            return 1
        fi
        COUNT=$COUNT+1
    done
    return 0
}
