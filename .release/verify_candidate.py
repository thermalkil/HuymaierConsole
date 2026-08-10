#!/usr/bin/env python3
import hashlib
import json
import os
import pathlib
import re
import struct
import sys
import zipfile


def fail(message: str) -> None:
    raise SystemExit(message)


def sha256(path: pathlib.Path) -> str:
    h = hashlib.sha256()
    with path.open('rb') as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b''):
            h.update(chunk)
    return h.hexdigest()


def main() -> None:
    root = pathlib.Path(os.environ.get('CANDIDATE_DIR', '/tmp/hc-candidate'))
    workspace = pathlib.Path(os.environ['GITHUB_WORKSPACE'])
    version = os.environ['VERSION']
    asset_name = os.environ['ASSET_NAME']
    package_root = os.environ['PACKAGE_ROOT'].strip('/\\')
    expected_sha = os.environ['EXPECTED_SHA'].lower()
    source_commit = os.environ['SOURCE_COMMIT'].lower()
    run_id = int(os.environ['RUN_ID'])
    run_attempt = int(os.environ['RUN_ATTEMPT'])

    zip_matches = list(root.rglob(asset_name))
    side_matches = list(root.rglob(asset_name + '.sha256'))
    validation_matches = list(root.rglob('candidate-validation.json'))
    if len(zip_matches) != 1 or len(side_matches) != 1 or len(validation_matches) != 1:
        fail(
            'Candidate artifact must contain exactly one ZIP, sidecar, and validation record; '
            f'found zip={len(zip_matches)} sidecar={len(side_matches)} validation={len(validation_matches)}'
        )

    zip_path, sidecar_path, validation_path = zip_matches[0], side_matches[0], validation_matches[0]
    actual_sha = sha256(zip_path)
    if actual_sha != expected_sha:
        fail(f'Candidate ZIP SHA-256 mismatch: expected {expected_sha}, found {actual_sha}')

    sidecar = sidecar_path.read_text(encoding='ascii').strip()
    match = re.match(r'^([0-9a-fA-F]{64})(?:\s+.+)?$', sidecar)
    if not match or match.group(1).lower() != actual_sha:
        fail('Candidate SHA-256 sidecar does not match the candidate ZIP.')

    validation = json.loads(validation_path.read_text(encoding='utf-8-sig'))
    expected_validation = {
        'version': version,
        'asset': asset_name,
        'sha256': actual_sha,
        'sourceCommit': source_commit,
        'architecture': 'x64',
        'gameInput': '3.5.262',
        'failureInjectionTests': 'success',
        'lockedIdenticalRepair': 'success',
        'lockedChangedFailClosedRepair': 'success',
        'unmanagedDataPreservation': 'success',
    }
    for key, expected in expected_validation.items():
        actual = validation.get(key, '')
        if str(actual).lower() != str(expected).lower():
            fail(f'Candidate validation mismatch for {key}: expected {expected!r}, found {actual!r}')
    if int(validation.get('runId') or 0) != run_id:
        fail('candidate-validation.json runId does not match the pinned release run.')
    if int(validation.get('runAttempt') or 0) != run_attempt:
        fail('candidate-validation.json runAttempt does not match the pinned release attempt.')
    if int(validation.get('packageFiles') or 0) <= 0:
        fail('candidate-validation.json does not contain a valid package file count.')

    prefix = package_root + '/'
    with zipfile.ZipFile(zip_path, 'r') as archive:
        raw_files = [
            name for name in archive.namelist()
            if name and not name.endswith(('/', '\\'))
        ]
        normalized = [name.replace('\\', '/') for name in raw_files]
        if not normalized:
            fail('Candidate ZIP has no files.')
        if len(set(normalized)) != len(normalized):
            fail('Candidate ZIP contains duplicate paths after Windows separator normalization.')
        raw_by_normalized = dict(zip(normalized, raw_files))

        def read_norm(name: str) -> bytes:
            raw = raw_by_normalized.get(name)
            if raw is None:
                fail(f'Candidate ZIP is missing {name}')
            return archive.read(raw)

        for name in normalized:
            path = pathlib.PurePosixPath(name)
            if path.is_absolute() or '..' in path.parts or not name.startswith(prefix):
                fail(f'Unsafe or unexpected ZIP entry: {name}')

        manifest_name = prefix + 'manifest.json'
        checks_name = prefix + 'checksums.sha256'
        compat_name = prefix + 'SHA256SUMS.txt'
        manifest = json.loads(read_norm(manifest_name).decode('utf-8-sig'))
        if str(manifest.get('version', '')) != version:
            fail('Packaged manifest version does not match release version.')

        checks = read_norm(checks_name).decode('utf-8')
        compat = read_norm(compat_name).decode('utf-8')
        if checks != compat:
            fail('Internal checksum manifests disagree.')

        expected_files: dict[str, str] = {}
        for line in checks.splitlines():
            if not line.strip():
                continue
            match = re.match(r'^([0-9a-fA-F]{64})  (.+)$', line)
            if not match:
                fail(f'Invalid internal checksum row: {line}')
            relative = match.group(2).replace('\\', '/')
            rel_path = pathlib.PurePosixPath(relative)
            if rel_path.is_absolute() or '..' in rel_path.parts:
                fail(f'Unsafe internal checksum path: {relative}')
            if relative in expected_files:
                fail(f'Duplicate internal checksum path: {relative}')
            expected_files[relative] = match.group(1).lower()

        actual_relative = {
            name[len(prefix):]
            for name in normalized
            if name not in (checks_name, compat_name)
        }
        if actual_relative != set(expected_files):
            missing = sorted(set(expected_files) - actual_relative)
            extra = sorted(actual_relative - set(expected_files))
            fail(f'Closed package mismatch. missing={missing} extra={extra}')

        for relative, expected_hash in expected_files.items():
            data = read_norm(prefix + relative)
            if hashlib.sha256(data).hexdigest() != expected_hash:
                fail(f'Internal checksum mismatch: {relative}')

        for relative in (
            'HuymaierConsole.exe',
            'HuymaierGameInputBridge.dll',
            'FSEPackage/HuymaierFSEHost.exe',
        ):
            data = read_norm(prefix + relative)
            if len(data) < 0x40 or data[:2] != b'MZ':
                fail(f'Invalid PE file: {relative}')
            pe_offset = struct.unpack_from('<I', data, 0x3C)[0]
            if data[pe_offset:pe_offset + 4] != b'PE\0\0':
                fail(f'Invalid PE signature: {relative}')
            machine = struct.unpack_from('<H', data, pe_offset + 4)[0]
            if machine != 0x8664:
                fail(f'{relative} is not x64: machine=0x{machine:04x}')

        forbidden_prefixes = (
            '.development/', '.source/', '.release/', '.github/', '.build/', 'Docs/'
        )
        forbidden_names = [
            rel for rel in actual_relative
            if rel.startswith(forbidden_prefixes)
            or re.match(r'^BUILD-VALIDATION.*\.txt$', rel, re.I)
            or re.match(r'^RELEASE_NOTES-v.*\.txt$', rel, re.I)
        ]
        if forbidden_names:
            fail(f'Developer/history payload survived production candidate: {sorted(forbidden_names)}')

    (workspace / asset_name).write_bytes(zip_path.read_bytes())
    (workspace / (asset_name + '.sha256')).write_bytes(sidecar_path.read_bytes())
    print(f'Exact candidate promotion verified: {asset_name} sha256={actual_sha}')


if __name__ == '__main__':
    main()
