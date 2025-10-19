
echo "$GHCR_TOKEN" | podman login ghcr.io -u "$GHCR_USER" --password-stdin

# We need the images remotely first, so we can reference them in the manifest add step
podman push --compression-format=gzip ${XTR_IMG}:${XTR_TAG}-amd64
podman push --compression-format=gzip ${XTR_IMG}:${XTR_TAG}-arm64

# Remove stale manifest
podman manifest rm ${XTR_IMG}:${XTR_TAG}

# We need to distribute the image for multiple architectures under one name:tag
podman manifest create ${XTR_IMG}:${XTR_TAG}

# Manifest references the remote images
podman manifest add    ${XTR_IMG}:${XTR_TAG} docker://${XTR_IMG}:${XTR_TAG}-amd64
podman manifest add    ${XTR_IMG}:${XTR_TAG} docker://${XTR_IMG}:${XTR_TAG}-arm64

# The created manifest should reference the digests of remote images
echo "Images in the local manifest:"
podman manifest inspect ${XTR_IMG}:${XTR_TAG} | jq '.manifests[] | {platform, digest}'

# The “fat” tag is usable everywhere. Using docker schema is the most compatible
podman manifest push --all --format docker ${XTR_IMG}:${XTR_TAG}

# Inspects the images on ghcr
echo "Images in the remote manifest:"
skopeo inspect --raw docker://${XTR_IMG}:${XTR_TAG} | jq -r '.manifests[] | {platform, digest}'


echo "Fat manifest images locally"
podman images --filter manifest=true

echo "Regular images locally"
podman images --filter manifest=false


# The manifest process orphans build-images
#podman image prune --filter dangling=true -f