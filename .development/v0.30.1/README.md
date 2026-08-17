# Huymaier Console v0.30.1

Development line following public v0.3.0.

Current goals:
- 3D model brightness customization range: 0-200%.
- Replace continuous 360-degree shelf turntable motion with a bounded, smooth fan-style idle presentation motion.
- Repair in-console self-update behavior so legacy v0.26.x installs can move directly to v0.30.1 and future public versions without the version-reset comparison trap.
- Keep release ZIP + `.sha256` integrity verification and transactional silent install/relaunch behavior intact.

Version-reset note:
- Public v0.3.0 promoted the exact legacy v0.26.5 candidate bytes. A normal `System.Version` comparison treats `0.3.0` as older than `0.26.x`, which caused older installs to display the public release while withholding the actionable update path.
- v0.30.1 uses its real `0.30.1` package identity, which is natively newer than the legacy v0.26.x line, and the updater now also understands the one-time v0.3.0 ↔ v0.26.5 public-version alias.