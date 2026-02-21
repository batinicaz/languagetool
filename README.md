# languagetool

ARM64 Docker image for [LanguageTool](https://github.com/languagetool-org/languagetool) with FastText language detection.

Built from source with a minimal JRE (jlink), runs as non-root user (UID 783), zero capabilities required.

Built on push to main and scanned for vulnerabilities using [Trivy](https://github.com/aquasecurity/trivy).

## Features

- ARM64 native
- Minimal Alpine base with custom jlink JRE
- FastText language identification included
- Non-root from start (UID 783, never root)
- Read-only filesystem compatible
- N-gram support via volume mount at `/ngrams`
