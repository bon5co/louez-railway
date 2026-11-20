# louez-railway

Railway wrapper image for [Louez](https://github.com/Synapsr/Louez) (AGPL-3.0), an open-source equipment-rental platform.

The image is the upstream `synapsr/louez` image pinned by digest, plus a boot script that:

1. refuses to start without an owner password of 12 or more characters, an auth secret, a database URL and S3 settings;
2. starts Louez on a private loopback port and registers the owner account from `ADMIN_EMAIL` and `ADMIN_PASSWORD`, which closes public registration (Louez allows exactly one first account in standalone mode);
3. restarts Louez on Railway's `PORT`, so the open sign-up page is never reachable from the internet.

A second boot is idempotent: registration is already closed, and the script only reports whether the owner password still matches.

Published as `ghcr.io/bon5co/louez-railway`.
