#!/bin/bash

if [ $# -ne 3 ]
then
    echo "Missing arguments.  Did you run 'make verify KANIKO_IMAGE_TAR=/path/to/kaniko_image_tar IMAGE_TAG=image_tag ENCLAVE=https://example.com/attestation'?" >&2
    exit 1
fi
kaniko_image_tar="$1"
repro_image="$2"
enclave="$3"

docker load -i "$(kaniko_image_tar)" # import the docker image from the tar onto this host
echo "[+] Building reproducible reference image.  This may take a while." >&2
echo "$repro_image"
cat > Dockerfile <<EOF
FROM public.ecr.aws/amazonlinux/amazonlinux:2

# See:
# https://docs.aws.amazon.com/enclaves/latest/user/nitro-enclave-cli-install.html#install-cli
RUN amazon-linux-extras install aws-nitro-enclaves-cli
RUN yum install aws-nitro-enclaves-cli-devel -y
RUN nitro-cli -V

# Now turn the local Docker image into an Enclave Image File (EIF).
CMD ["/bin/bash", "-c", \
     "nitro-cli build-enclave --docker-uri $repro_image --output-file dummy.eif 2>/dev/null"]
EOF

# We're using --no-cache because AWS's nitro-cli may update, at which point the
# builder image will use an outdated copy, which will result in an unexpected
# PCR0 value.
echo "[+] Building builder image." >&2
builder_image=$(docker build --no-cache --quiet . | cut -d ':' -f 2)
local_pcr0=$(docker run -ti -v /var/run/docker.sock:/var/run/docker.sock \
             "$builder_image" | jq --raw-output ".Measurements.PCR0")

# Request attestation document from the enclave.
echo "[+] Fetching remote attestation." >&2
remote_pcr0=$(./fetch-attestation -url "$enclave" 2>/dev/null)

if [ "$local_pcr0" = "$remote_pcr0" ]
then
    echo "Remote image is identical to local image."
else
    echo -e "WARNING: Remote image IS NOT identical to local image!\n"
    echo -e "\tExpected: $local_pcr0"
    echo -e "\tReceived: $remote_pcr0"
fi
