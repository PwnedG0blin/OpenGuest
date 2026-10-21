# Stratovo 1.0 Beta 7.2 · Repository migration update

Build **1027** prepares the public updater for the repository name **Stratovo**.
The releases API checks Stratovo first, with OpenGuest as a fallback before the rename. Release and download
validation accepts both official names, with matching repository, tag and SHA-256.
Existing settings, guest storage and machine identities remain unchanged.

This release includes Beta 7.1’s Android full-resolution streaming, quality
selection, media-volume controls and Midnight/Glass windows and dialogs.

## Install before renaming the public repository

Install this migration release while the repository is still named **OpenGuest**.
Older installed public apps validate only OpenGuest release URLs; GitHub redirects
alone cannot repair that code. After renaming, those old versions need a manual
installation of Beta 7.2 or newer. Keep OpenGuest redirect links and do not create
a replacement repository at that name. The private update channel is separate.

Actual Android game performance and audio require testing on the user's Mac.
