#!/usr/bin/env python3
"""Generic SOPS preparation; application requirements belong to the project."""
import argparse
import fcntl
import hashlib
import io
import json
import os
from pathlib import Path
import platform
import re
import shutil
import subprocess
import sys
import tarfile
import tempfile
import urllib.request

ROOT = Path(os.environ.get('HV_ROOT', Path(__file__).resolve().parents[1]))
ENV_KEY = re.compile(r'[A-Za-z_][A-Za-z0-9_]*\Z')

def fail(message):
    raise ValueError(message)

def tool(name):
    found = shutil.which(name)
    local = Path(os.environ.get('HV_LOCAL_BIN_DIR', str(Path.home() / '.local/bin'))) / name
    if found:
        return found
    if local.is_file() and os.access(local, os.X_OK):
        return str(local)
    fail(f'{name} is missing; run hv sops init')

def call(args, data=None):
    result = subprocess.run(args, input=data, capture_output=True)
    if result.returncode:
        # Tool errors can contain input values. Keep credentials out of logs.
        fail(f'{Path(args[0]).name} failed; check the file, encryption rules and key access')
    return result.stdout

def atomic_write(path, data, mode=0o600):
    path = Path(path)
    with tempfile.NamedTemporaryFile(dir=path.parent, prefix='.' + path.name + '.', delete=False) as stream:
        temporary = Path(stream.name)
        try:
            os.fchmod(stream.fileno(), mode)
            stream.write(data)
            stream.flush()
            os.fsync(stream.fileno())
        except BaseException:
            temporary.unlink(missing_ok=True)
            raise
    try:
        os.replace(temporary, path)
    finally:
        temporary.unlink(missing_ok=True)

def create_private(path, data):
    descriptor = os.open(path, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
    with os.fdopen(descriptor, 'wb') as stream:
        stream.write(data)

def identity_path():
    default = Path(os.environ.get('XDG_CONFIG_HOME', str(Path.home() / '.config'))) / 'sops/age/keys.txt'
    return Path(os.environ.get('SOPS_AGE_KEY_FILE', str(default))).expanduser()

def recipients():
    path = identity_path()
    if not path.is_file():
        fail('age identity is missing; run hv sops init')
    public = call([tool('age-keygen'), '-y', str(path)]).decode().strip().splitlines()
    if not public or any(not item.startswith('age1') for item in public):
        fail('Expected a native age identity file')
    return public

def initialize():
    if platform.system() != 'Linux':
        fail('Automatic installation currently supports Linux only')
    arch = {'x86_64': 'amd64', 'aarch64': 'arm64'}.get(platform.machine())
    if not arch:
        fail('Unsupported host architecture')
    config = json.loads((ROOT / 'config.json').read_text())
    install_dir = Path(os.environ.get('HV_LOCAL_BIN_DIR', str(Path.home() / '.local/bin')))
    for name, binaries, repo in [('sops', ('sops',), 'getsops/sops'), ('age', ('age', 'age-keygen'), 'FiloSottile/age')]:
        try:
            for binary in binaries:
                tool(binary)
            print(f'{name}: using existing installation')
            continue
        except ValueError:
            pass
        version = config['dependencies'][name]
        digest = config['toolChecksums'][name][version][arch]
        asset = f'sops-v{version}.linux.{arch}' if name == 'sops' else f'age-v{version}-linux-{arch}.tar.gz'
        url = f'https://github.com/{repo}/releases/download/v{version}/{asset}'
        print(f'Installing {name} {version} ({arch})...')
        request = urllib.request.Request(url, headers={'User-Agent': 'HelmVerse'})
        with urllib.request.urlopen(request, timeout=60) as response:
            downloaded = response.read()
        if hashlib.sha256(downloaded).hexdigest() != digest:
            fail(f'{name} checksum verification failed')
        install_dir.mkdir(parents=True, exist_ok=True)
        if name == 'sops':
            atomic_write(install_dir / name, downloaded, 0o755)
        else:
            with tarfile.open(fileobj=io.BytesIO(downloaded), mode='r:gz') as archive:
                for binary in binaries:
                    member = archive.getmember('age/' + binary)
                    if not member.isfile():
                        fail('Unexpected age archive content')
                    atomic_write(install_dir / binary, archive.extractfile(member).read(), 0o755)
    key = identity_path()
    if key.exists():
        os.chmod(key, 0o600)
        print(f'Using existing age identity: {key}')
    else:
        key.parent.mkdir(parents=True, exist_ok=True, mode=0o700)
        create_private(key, call([tool('age-keygen')]))
        print(f'Created age identity: {key}')
    for public in recipients():
        print('Public recipient:', public)
    print('Keep a separate recoverable backup of the private identity file.')

def parse_dotenv(text):
    """Parse literal dotenv values; never evaluate shell or expand variables."""
    if '\x00' in text:
        fail('NUL bytes are not supported')
    values = {}
    lines = iter(enumerate(text.splitlines(), 1))
    for number, line in lines:
        line = line.strip()
        if not line or line.startswith('#'):
            continue
        if line.startswith('export '):
            line = line[7:].lstrip()
        key, separator, value = line.partition('=')
        key, value = key.strip(), value.strip()
        if not separator or not ENV_KEY.fullmatch(key):
            fail(f'Invalid variable assignment at line {number}')
        if key in values:
            fail(f'Duplicate variable at line {number}: {key}')
        if value.startswith(('"', "'")):
            quote, collected, position = value[0], [], 1
            while True:
                if position >= len(value):
                    try:
                        _, continuation = next(lines)
                    except StopIteration:
                        fail(f'Unclosed quote at line {number}')
                    value += '\n' + continuation
                character = value[position]
                if character == quote:
                    remainder = value[position + 1:].strip()
                    if remainder and not remainder.startswith('#'):
                        fail(f'Unexpected text after quoted value at line {number}')
                    break
                if character == '\\' and quote == '"' and position + 1 < len(value):
                    following = value[position + 1]
                    escapes = {'n': '\n', 'r': '\r', 't': '\t', '"': '"', '\\': '\\'}
                    if following in escapes:
                        collected.append(escapes[following])
                        position += 2
                        continue
                collected.append(character)
                position += 1
            value = ''.join(collected)
        else:
            value = re.split(r'\s+#', value, maxsplit=1)[0].rstrip()
        values[key] = value
    return values

def validate(document, required=()):
    if not isinstance(document, dict) or set(document) != {'secret'}:
        fail('Expected a single root mapping named secret')
    values = document['secret']
    if not isinstance(values, dict) or any(not ENV_KEY.fullmatch(k) or not isinstance(v, str) for k, v in values.items()):
        fail('Secret entries must have valid environment variable names and string values')
    missing = [name for name in required if not values.get(name)]
    if missing:
        fail('Project requires non-empty secret fields: ' + ', '.join(missing))
    return values

def prepare(args):
    parser = argparse.ArgumentParser(prog='hv sops', description='Create or merge encrypted Helm secret values from a project dotenv file.')
    parser.add_argument('-p', '--project', required=True)
    parser.add_argument('--env', choices=('dev', 'prod'), default='dev')
    options = parser.parse_args(args)
    if not re.fullmatch(r'[a-z0-9](?:[a-z0-9-]*[a-z0-9])?', options.project):
        fail('Invalid project name')
    project = Path(os.environ.get('HV_PROJECTS_DIR', str(ROOT / 'projects'))) / options.project
    if not (project / 'helm-chart/Chart.yaml').is_file():
        fail('Project does not contain a Helm chart')
    source = project / ('.env.secret' if options.env == 'dev' else '.env.secret.prod')
    tracked = subprocess.run(['git', '-C', str(project), 'ls-files', '--error-unmatch', '--', str(source)], capture_output=True)
    if tracked.returncode == 0:
        fail('The plaintext input is tracked by Git; remove it from the index before importing')
    ignore = project / '.gitignore'
    existing = ignore.read_text() if ignore.exists() else ''
    rules = ('/.env.secret', '/.env.secret.*', '!/.env.secret.example', '/secrets/*', '!/secrets/*.enc.yaml')
    additions = [rule for rule in rules if rule not in existing.splitlines()]
    if additions:
        atomic_write(ignore, (existing.rstrip() + '\n' + '\n'.join(additions) + '\n').lstrip().encode(), 0o644)
    if not source.exists():
        example = project / '.env.secret.example'
        content = example.read_bytes() if example.exists() else b'# Add KEY=value entries, save, and run hv sops again.\n# Values are literal; shell variables and commands are not evaluated.\n'
        create_private(source, content)
        print(f'Created {source}. Fill it in, then rerun hv sops -p {options.project} --env {options.env}.')
        return 0
    os.chmod(source, 0o600)
    updates = parse_dotenv(source.read_text(encoding='utf-8-sig'))
    if not updates:
        fail(f'No variables found. Fill in {source} and rerun the command')
    sops = tool('sops')
    config = project / '.sops.yaml'
    if not config.exists():
        public = ','.join(recipients())
        content = f'creation_rules:\n  - path_regex: secrets/values\\.(dev|prod)\\.enc\\.yaml$\n    encrypted_regex: ^secret$\n    age: {public}\n'
        create_private(config, content.encode())
        os.chmod(config, 0o644)
    directory = project / 'secrets'
    directory.mkdir(exist_ok=True, mode=0o700)
    output = directory / f'values.{options.env}.enc.yaml'
    with (directory / ('.' + output.name + '.lock')).open('a') as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        values = {}
        if output.exists():
            values = validate(json.loads(call([sops, 'decrypt', '--output-type', 'json', str(output)])))
        added = len(set(updates) - set(values))
        values.update(updates)
        document = {'secret': values}
        payload = json.dumps(document).encode()
        encrypted = call([sops, '--config', str(config), 'encrypt', '--filename-override', str(output), '--input-type', 'json', '--output-type', 'yaml', '/dev/stdin'], payload)
        checked = call([sops, 'decrypt', '--input-type', 'yaml', '--output-type', 'json', '/dev/stdin'], encrypted)
        if json.loads(checked) != document:
            fail('Encrypted values did not pass round-trip verification')
        atomic_write(output, encrypted)
    print(f'Wrote {output}: {added} added, {len(updates) - added} updated, {len(values)} total fields.')
    print('Plaintext input retained locally with mode 600; deployment reads only the encrypted file.')
    return 0

def main():
    action, *args = sys.argv[1:]
    if action == 'init':
        if args:
            if args == ['--help']:
                print('Usage: hv sops init\nInstall missing tools and create or reuse the age identity. Honors SOPS_AGE_KEY_FILE and HV_LOCAL_BIN_DIR.')
                return 0
            fail('Usage: hv sops init')
        initialize()
    elif action == 'validate':
        validate(json.load(sys.stdin), args)
    elif action == 'prepare':
        return prepare(args)
    else:
        fail('Unknown SOPS operation')
    return 0

if __name__ == '__main__':
    try:
        sys.exit(main())
    except (ValueError, OSError, KeyError) as error:
        # Do not serialize input documents or subprocess output in errors.
        message = str(error) if isinstance(error, ValueError) and not isinstance(error, json.JSONDecodeError) else 'Operation failed; check input format, paths, permissions and tool configuration'
        print('Error: ' + message, file=sys.stderr)
        sys.exit(1)
