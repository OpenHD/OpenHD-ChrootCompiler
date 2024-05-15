#!/bin/bash -e
# shellcheck disable=SC2119,SC1091

IMAGE_TYPE=$1
TESTING=$2

#UPDATE to newest version
git clone https://github.com/OpenHD/OpenHD-ImageBuilder
mv OpenHD-ImageBuilder/images .
mv OpenHD-ImageBuilder/stages/01-Baseimage stages/
rm -Rf OpenHD-ImageBuilder

if [[ "${IMAGE_TYPE}" == "" ]]; then
    echo "Usage: ./build.sh pi-bullseye"
    echo ""
    echo "Target boards:"
    echo ""
    ls -1 images/
    echo ""
    exit 1
fi

if [[ ! -f ./images/${IMAGE_TYPE} ]]; then
    echo "Invalid image type: ${IMAGE_TYPE}"
    exit 1
fi

source ./images/${IMAGE_TYPE}

echo ""


run_stage(){
    STAGE="$(basename "${STAGE_DIR}")"
    STAGE_WORK_DIR="${WORK_DIR}/${STAGE}"

    log ""
    log ""
    log "======================================================"
    log "Begin ${STAGE_WORK_DIR}"
    pushd "${STAGE_DIR}" > /dev/null

    # Create the Work folder
    mkdir -p "${STAGE_WORK_DIR}"

    # Check wether to skip or not
    echo "-------------------------------------------------------"
    echo "--------------check-------------size-------------------"
    df -h
    if [ ! -f "${STAGE_WORK_DIR}/SKIP" ]; then
        # mount the image for this stage
        if [ ! -f "${STAGE_WORK_DIR}/SKIP_IMAGE" ]; then
            # Copy the image from the previous stage
            if [ -f "${PREV_WORK_DIR}/IMAGE.img" ]; then
                unmount_image
                cp "${PREV_WORK_DIR}/IMAGE.img" "${STAGE_WORK_DIR}/IMAGE.img"
                mount_image
                echo "deleteing last work dir...SMALL option"
                rm -r "${PREV_WORK_DIR}"
            else
                log "[ERROR] No image to copy in ${PREV_WORK_DIR}/"
            fi
        fi

        # iterate different files
        for i in {00..99}; do

            if [ -x ${i}-run.sh ]; then
                log "Begin ${STAGE_DIR}/${i}-run.sh"
                ./${i}-run.sh
                log "End ${STAGE_DIR}/${i}-run.sh"
            fi

            if [ -f ${i}-run-chroot.sh ]; then
                log "Begin ${STAGE_DIR}/${i}-run-chroot.sh"
                on_chroot < ${i}-run-chroot.sh
                log "End ${STAGE_DIR}/${i}-run-chroot.sh"
            fi

        done
    fi

    # SKIP this stage next time
    touch "${STAGE_WORK_DIR}/SKIP"

    PREV_STAGE="${STAGE}"
    PREV_STAGE_DIR="${STAGE_DIR}"
    PREV_WORK_DIR="${WORK_DIR}/${STAGE}"

    if [ ! -f "${STAGE_WORK_DIR}/SKIP_IMAGE" ]; then
        unmount_image
    fi

    popd > /dev/null
    log "End ${STAGE_WORK_DIR}"
}

if [ "$(id -u)" != "0" ]; then
    echo "Please run as root" 1>&2
    exit 1
fi

# Variables
export IMG_DATE="${IMG_DATE:-"$(date +%Y-%m-%d)"}"

BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export SCRIPT_DIR="${BASE_DIR}/scripts"
export WORK_DIR="${BASE_DIR}/work-${IMAGE_TYPE}"
export DEPLOY_DIR=${DEPLOY_DIR:-"${BASE_DIR}/deploy"}
export LOG_FILE="${WORK_DIR}/build.log"

mkdir -p "${WORK_DIR}"

export BASE_DIR

export BASE_IMAGE_SHA256

export LEGACY
export BASE_IMAGE_Mirror
export HAS_CUSTOM_KERNEL
export BIT
export ROOT_PART
export BOOT_PART
export HAVE_BOOT_PART
export HAVE_CONF_PART
export OPENHD_PACKAGE
export KERNEL_PACKAGE
export OS
export IMAGE_TYPE
export DISTRO
export BASE_IMAGE_URL
export BASE_IMAGE
export TESTING
export SMALL
export HAS_CUSTOM_BASE

export CLEAN
export IMG_NAME

export APT_CACHER_NG_URL
export APT_CACHER_NG_ENABLED

export STAGE
export STAGE_DIR
export STAGE_WORK_DIR
export PREV_STAGE
export PREV_STAGE_DIR
export PREV_WORK_DIR
export ROOTFS_DIR
export PREV_ROOTFS_DIR
export IMG_SUFFIX

# shellcheck source=scripts/common.sh
source "${SCRIPT_DIR}/common.sh"

log "IMG ${BASE_IMAGE}"
log "Begin ${BASE_DIR}"

# Iterate trough the steps
find ./stages -name '*.sh' -type f | xargs chmod 775
for STAGE_DIR in "${BASE_DIR}/stages/"*; do
    if [ -d "${STAGE_DIR}" ]; then
        run_stage
    fi
done

cd ${BASE_DIR}
if [ -z "$(ls -A out 2>/dev/null)" ]; then echo "---------------> build failed :(" && exit 1; fi
echo "---------------> build successful  :)"
log "End ${BASE_DIR}"
