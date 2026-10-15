# Stability and security status

OpenGuest 0.1 is a source prototype. Native ARM64 compilation and all 13 unit tests passed in GitHub Actions. Guest integration tests, a security audit and extended stability tests remain open. No crash-free or isolation guarantee is made.

Guest state is persistent: Android user data, Windows disk, UEFI variables and TPM state are not reset between sessions. Prefer normal guest shutdown. Forced termination and host/guest crashes can still lose recent changes. The app does not supply automatic backups or recover game cloud saves itself.

Processes run as the current user. No privileged helper, root request, host directory sharing, telemetry or public VNC listener is implemented. APKs are installed into the selected guest. Google credentials are entered only in the guest. Optional Windows local-account credentials are temporarily present in private setup media and cleared from normal app settings; setup encoding is reversible and is not encryption. A crash may leave private temporary setup files until manually removed.

The streaming server is downloaded separately from the exact upstream release, checked against upstream SHA-256 metadata and checked again before use. This does not replace a dependency audit. Keep the protocol/server version paired and review later upstream fixes before distributing a public binary.

Before claiming a stable release, complete the Mac acceptance tests, validate suitable Windows firmware, review guest parser/process boundaries, test state retention across interruptions, and sign/notarize the public macOS app. Never disable Gatekeeper to make a release installable.

The source archive has no live support or reporting endpoint. When a public repository is created, configure private vulnerability reporting there before accepting sensitive reports.
