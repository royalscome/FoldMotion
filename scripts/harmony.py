#!/usr/bin/env python3
"""Build/test/package FoldMotion with a local DevEco Studio installation."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import tarfile

ROOT = Path(__file__).resolve().parents[1]
HAR = ROOT / 'fold_motion/build/default/outputs/default/fold_motion.har'


def sdk_environment():
    env = os.environ.copy()
    studio = Path(env.get('DEVECO_STUDIO_HOME', '/Applications/DevEco-Studio.app/Contents'))
    if (studio / 'Contents').is_dir():
        studio = studio / 'Contents'
    if (studio / 'sdk').is_dir():
        env.setdefault('DEVECO_SDK_HOME', str(studio / 'sdk'))
    java = studio / 'jbr/Contents/Home'
    if not java.is_dir():
        java = studio / 'jbr'
    if java.is_dir():
        env.setdefault('JAVA_HOME', str(java))
    return studio, env


def executable(name, studio):
    override = os.environ.get(f'{name.upper()}_BINARY')
    if override:
        return override
    tool = 'hvigorw' if name == 'hvigor' else name
    suffix = '.bat' if os.name == 'nt' else ''
    bundled = studio / f'tools/{name}/bin/{tool}{suffix}'
    found = str(bundled) if bundled.is_file() else shutil.which(tool)
    if not found:
        raise RuntimeError(f'{tool} not found. Set DEVECO_STUDIO_HOME or {name.upper()}_BINARY.')
    return found


def run(command, env):
    print('+ ' + ' '.join(str(arg) for arg in command), flush=True)
    subprocess.run(command, cwd=ROOT, env=env, check=True)


def hvigor(task, module, mode, studio, env):
    run([executable('hvigor', studio), task, '--mode', 'module',
         '-p', f'module={module}@default', '-p', 'product=default',
         '-p', f'buildMode={mode}', '--no-daemon'], env)


def verify_archive():
    metadata = json.loads((ROOT / 'fold_motion/oh-package.json5').read_text())
    with tarfile.open(HAR, 'r:*') as archive:
        names = set(archive.getnames())
        required = ['Index.d.ets', 'ets/modules.abc', 'LICENSE', 'README.md',
                    'src/main/ets/FoldMotion.d.ets',
                    'src/main/ets/FoldMotionController.d.ets',
                    'src/main/ets/FoldMotionDirectionModel.d.ets',
                    'src/main/ets/FoldMotionModel.d.ets', 'oh-package.json5']
        for name in required:
            if f'package/{name}' not in names:
                raise RuntimeError(f'HAR missing {name}')
        license_text = archive.extractfile('package/LICENSE').read()
        if license_text != (ROOT / 'LICENSE').read_bytes():
            raise RuntimeError('HAR license differs from root LICENSE')
        if archive.extractfile('package/README.md').read() != (ROOT / 'fold_motion/README.md').read_bytes():
            raise RuntimeError('HAR README differs from source README')
        package = json.loads(archive.extractfile('package/oh-package.json5').read())
        for key in ['name', 'version', 'license']:
            if package.get(key) != metadata[key]:
                raise RuntimeError(f'HAR {key} does not match source manifest')
        if package.get('dependencies', {}):
            raise RuntimeError('Unexpected HAR runtime dependencies')
    print(f'Verified {metadata["name"]} {metadata["version"]}: public API, license and metadata.')
    return metadata


def test(studio, env):
    result = ROOT / 'fold_motion/.test/default/intermediates/test/coverage_data/test_result.txt'
    # A stale report must never make a failed test invocation look successful.
    result.unlink(missing_ok=True)
    hvigor('test', 'fold_motion', 'debug', studio, env)
    report = result.read_text()
    print(report)
    counts = re.search(r'Tests run:\s*(\d+).*?Failure:\s*(\d+).*?Error:\s*(\d+).*?Pass:\s*(\d+).*?Ignore:\s*(\d+)', report, re.S)
    if not counts:
        raise RuntimeError('Cannot verify the Hypium test report')
    total, failures, errors, passed, ignored = map(int, counts.groups())
    if total == 0 or failures or errors or ignored or passed != total:
        raise RuntimeError('Hypium tests did not all pass')


def package(studio, env):
    hvigor('assembleHar', 'fold_motion', 'release', studio, env)
    metadata = verify_archive()
    destination = ROOT / 'dist' / f'fold-motion-{metadata["version"]}.har'
    destination.parent.mkdir(exist_ok=True)
    shutil.copy2(HAR, destination)
    digest = hashlib.sha256(destination.read_bytes()).hexdigest()
    (destination.parent / 'SHA256SUMS').write_text(f'{digest}  {destination.name}\n')
    print(f'Release artifact: {destination}')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('command', choices=['install', 'test', 'build', 'demo', 'package', 'check'])
    args = parser.parse_args()
    studio, env = sdk_environment()
    if args.command in ['install', 'check']:
        run([executable('ohpm', studio), 'install', '--all'], env)
    if args.command in ['test', 'check']:
        test(studio, env)
    if args.command == 'build':
        hvigor('assembleHar', 'fold_motion', 'release', studio, env)
        verify_archive()
    if args.command in ['demo', 'check']:
        # Unsigned build; device signing is configured privately in DevEco Studio.
        hvigor('assembleHap', 'entry', 'debug', studio, env)
    if args.command in ['package', 'check']:
        package(studio, env)


if __name__ == '__main__':
    try:
        main()
    except (RuntimeError, OSError, ValueError, subprocess.CalledProcessError) as error:
        raise SystemExit(str(error)) from error
