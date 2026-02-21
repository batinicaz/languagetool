# template-build-docker-image

Template repo for building docker images and pushing to GHCR.

Images are built automatically every day at 2AM on the main branch and scanned using Aqua's Trivvy.

## Usage

Once a new repo is created from this template, you should:

1. Update the [Dockerfile](./Dockerfile) to match your needs. Recommend building the final image from one of [chainguards](https://edu.chainguard.dev/chainguard/chainguard-images/reference/).
2. Update the [action.yml](./.github/actions/docker/action.yml)
   1. Replace the uses of `find-latest-tag` as needed for the components you wish to include the latest versions of in your image.
   2. If not required remove the `strip-v-from-tag` step or expand if more versions are needed in sem ver only format.
   3. Update the build arguments as needed for the docker build command.
   4. Replace the `Clone test repo for validating image` & `Test image` steps with appropriate tests for your image.
3. Update this README. Here is an example:
```markdown
# <imageName>

Builds an image containing:

* <tools>

Built every day at 2AM to get latest changes and scanned for vulnerabilities using Aqua's [Trivy](https://github.com/aquasecurity/trivy).

## Usage

You can use the image in GitHub actions with a job definition like the one below:

```yaml
  job:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3

      - name: Run image
        uses: docker://ghcr.io/batinicaz/<imageName>:<imageTag>
```