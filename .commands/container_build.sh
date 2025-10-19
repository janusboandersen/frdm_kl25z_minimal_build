
# Github Actions needs amd64 (x86_64) architecture
podman build --rm --force-rm --squash-all --target final --arch amd64 -t ${XTR_IMG}:${XTR_TAG}-amd64 -f .docker/Dockerfile .
echo "Local AMD64 image:"
podman image inspect ${XTR_IMG}:${XTR_TAG}-amd64 --format '{{.Digest}}'
podman image inspect ${XTR_IMG}:${XTR_TAG}-amd64 --format '{{.Config.Env}}'
podman image tree ${XTR_IMG}:${XTR_TAG}-amd64

# Local Podman and devcontainer runs on Apple Silicon
podman build --rm --force-rm --squash-all --target final --arch arm64 -t ${XTR_IMG}:${XTR_TAG}-arm64 -f .docker/Dockerfile .
echo "Local ARM64 image:"
podman image inspect ${XTR_IMG}:${XTR_TAG}-arm64 --format '{{.Digest}}'
podman image inspect ${XTR_IMG}:${XTR_TAG}-arm64 --format '{{.Config.Env}}'
podman image tree ${XTR_IMG}:${XTR_TAG}-arm64

# 
podman image prune -f