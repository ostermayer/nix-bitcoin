- **Q:** My disk space is getting low due to nix.\
  **A:** run `nix-collect-garbage -d`

- **Q:** Where is `sudo`?\
  **A:** After [CVE-2021-3156](https://www.openwall.com/lists/oss-security/2021/01/26/3),
  we've replaced `sudo` with OpenBSD's `doas` for users of the `secure-node.nix` template.
  It has greatly reduced complexity and is therefore less likely to be a source of
  severe vulnerabilities in the future.
