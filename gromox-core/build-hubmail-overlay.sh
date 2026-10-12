#!/usr/bin/env bash
# Build + push the durable HubMail overlay image, then print the GitOps bump.
#
# This reproduces the running hubmail-core with BOTH hand-made customisations
# baked in reproducibly (see Dockerfile.hubmail-overlay):
#   1. the admin "DNS Setup" page, and
#   2. the "Gromox services" From-name removal.
#
# Run on the build host (.80 / boca-k3-build-node1), which is logged in to GHCR.
# Deploy is GitOps: bump the digest this prints into
#   manifests/hubmail-staging/20-core.yaml   (Argo app "hubmail-staging"),
# commit + push to the gitops repo, then let Argo sync.
set -euo pipefail

cd "$(dirname "$0")"

# Date-stamped, human-readable tag; the deploy pins the immutable digest, not this.
TAG="${1:-hubmail-overlay-$(date +%Y%m%d)}"
IMG="ghcr.io/jesseframework/hubmail-core:${TAG}"

echo "=== building ${IMG} ==="
# --provenance/--sbom off: keep a single-manifest image (k3s/containerd pulls it
# cleanly; attestation manifests have tripped digest pinning here before).
docker build --provenance=false --sbom=false \
  -f Dockerfile.hubmail-overlay \
  -t "${IMG}" \
  .

echo "=== pushing ${IMG} ==="
docker push "${IMG}"

echo "=== immutable digest to pin in GitOps (manifests/hubmail-staging/20-core.yaml) ==="
docker inspect --format '{{index .RepoDigests 0}}' "${IMG}"
