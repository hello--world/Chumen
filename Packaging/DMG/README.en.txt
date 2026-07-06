Chumen Installation Notes

System requirement: macOS 15 or later.

This release build uses local ad-hoc signing. It does not have an Apple Developer ID signature or notarization yet.
On another Mac, macOS may report that the app is damaged, cannot be opened, or was blocked from launching.

After confirming the DMG came from a trusted source, remove the quarantine attribute:

sudo xattr -r -d com.apple.quarantine /Applications/Chumen.app

If you have not moved the app to Applications yet, replace the path with its actual location, for example:

sudo xattr -r -d com.apple.quarantine "$HOME/Downloads/Chumen.app"

If the command reports No such xattr, the quarantine attribute is already gone and you can try opening Chumen again.
This step will not be needed after the app is signed and notarized with a Developer ID certificate.
