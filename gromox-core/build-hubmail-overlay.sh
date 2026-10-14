#!/usr/bin/env bash
# Build + push the durable HubMail overlay image, then print the GitOps bump.
#
# This produces hubmail-core = a core base (gromox + admin-API backends) with:
#   1. admin-web (DNS Setup page + 2FA tab) from the SOURCE-BUILT repo image
#      ghcr.io/jesseframework/hubmail-admin-web  (default :prod), and
#   2. the "Gromox services" From-name (GECOS) removal.
# See Dockerfile.hubmail-overlay.
#
# Usage: ./build-hubmail-overlay.sh [IMAGE_TAG] [ADMIN_WEB_IMAGE]
#   IMAGE_TAG        output hubmail-core tag (default: hubmail-overlay-<date>)
#   ADMIN_WEB_IMAGE  admin-web image to bake in; pin by @sha256 for a fully
#                    deterministic build (default: ghcr.io/jesseframework/hubmail-admin-web:prod)
#
# Run on the build host (.80 / boca-k3-build-node1), which is logged in to GHCR.
# Deploy is GitOps: bump the digest this prints into
#   manifests/hubmail-staging/20-core.yaml   (Argo app "hubmail-staging"),
# commit + push to the gitops repo, then let Argo sync.
set -euo pipefail

cd "$(dirname "$0")"

# Date-stamped, human-readable tag; the deploy pins the immutable digest, not this.
TAG="${1:-hubmail-overlay-$(date +%Y%m%d)}"
ADMIN_WEB="${2:-ghcr.io/jesseframework/hubmail-admin-web:prod}"
IMG="ghcr.io/jesseframework/hubmail-core:${TAG}"

echo "=== building ${IMG} (admin-web: ${ADMIN_WEB}) ==="
# --provenance/--sbom off: keep a single-manifest image (k3s/containerd pulls it
# cleanly; attestation manifests have tripped digest pinning here before).
docker build --provenance=false --sbom=false \
  --build-arg "ADMIN_WEB=${ADMIN_WEB}" \
  -f Dockerfile.hubmail-overlay \
  -t "${IMG}" \
  .

echo "=== pushing ${IMG} ==="
docker push "${IMG}"

echo "=== immutable digest to pin in GitOps (manifests/hubmail-staging/20-core.yaml) ==="
docker inspect --format '{{index .RepoDigests 0}}' "${IMG}"
