Chumen 安装说明

当前 release 包使用本地 ad-hoc 签名，没有 Apple Developer ID 签名和公证。
在其他 Mac 上首次打开时，macOS 可能提示应用已损坏、无法打开，或阻止启动。

确认 DMG 来源可信后，可以移除 quarantine 属性：

sudo xattr -r -d com.apple.quarantine /Applications/Chumen.app

如果还没有拖到 Applications，请把路径改成实际位置，例如：

sudo xattr -r -d com.apple.quarantine "$HOME/Downloads/Chumen.app"

如果命令提示 No such xattr，说明 quarantine 属性已经不存在，可以直接再次打开 Chumen。
后续正式签名和公证后，不需要这一步。
