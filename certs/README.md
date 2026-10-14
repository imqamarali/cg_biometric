# Certificate storage for MSIX signing

Drop your production code-signing certificate (`.pfx`) into this folder and update `pubspec.yaml` so `msix_config.certificate_path` points to it. Keep the certificate file and its password private — do not commit them. After you sign the MSIX file with a trusted certificate, the installer will no longer show the “publisher certificate could not be verified” warning.

If the certificate is issued by an internal CA, install its root/issuer certificates in the Trusted Root Certification Authorities store on every client machine before installing the package. Use `certmgr.msc` or `Import-Certificate` so the certificate chain is already trusted during installation.
