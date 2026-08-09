from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


def read(path):
    return (ROOT / path).read_text(encoding="utf-8-sig")


def write(path, text):
    (ROOT / path).write_text(text, encoding="utf-8")


def replace_once(text, old, new, label):
    count = text.count(old)
    if count != 1:
        raise RuntimeError(f"{label}: expected exactly one match, found {count}")
    return text.replace(old, new, 1)


# Keep the native bridge identity aligned with the v0.26.0 shell/manifest.
p = "Native/HuymaierConsole.NativeApp.cs"
s = read(p)
s = replace_once(
    s,
    '        public string Version { get { return "0.25.6"; } }',
    '        public string Version { get { return "0.26.0"; } }',
    "native bridge version",
)
write(p, s)

print("v0.26.0 native bridge version alignment completed.")
