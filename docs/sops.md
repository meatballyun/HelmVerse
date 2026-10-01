# Project deployment and Secret preparation

`hv deploy <project>` invokes `projects/<project>/helm-chart/deploy.sh`.
The project script selects values, chooses whether to load SOPS, validates its
application requirements, and calls Helm. There is no alternate Helm deployment
path in the CLI. `hv project validate` invokes the same script with `--dry-run`.

The functions in `utils/project_deploy.sh` are optional building blocks called
explicitly by project scripts. They provide argument parsing, memory-only
decryption, validation of explicitly requested fields, and Helm invocation.
The generic project template defaults to a 5-minute timeout. Project scripts
can choose a different timeout and wait for initialization Jobs when needed.
All scripts resolve their own paths and can be run directly from any working
directory. See [the project template](../projects/my-project/README.md) for
environment values, ConfigMap and Secret examples.

## Host initialization

```bash
hv sops init
```

This installs missing SOPS and age binaries into `~/.local/bin`, verifying the
fixed SHA-256 values in `config.json`. Linux amd64 and arm64 are supported.
Existing tools and age identities are reused. The default private identity is
`~/.config/sops/age/keys.txt`, with mode 600. `SOPS_AGE_KEY_FILE` selects another
identity path. Keep a separate recoverable backup of this identity; it never
belongs in Git. Public recipients in project `.sops.yaml` files may be committed.

Pinned downloads come from the official
[SOPS releases](https://github.com/getsops/sops/releases) and
[age releases](https://github.com/FiloSottile/age/releases).

## A new project

```bash
hv project create myapp --host myapp.example.com
hv sops -p myapp
```

The second command creates `projects/myapp/.env.secret` if missing, using the
project's `.env.secret.example` when present, and asks you to fill it in.
This first invocation does not create encrypted values. The input is private
(mode 600) and ignored by Git. Then:

```bash
# Edit the path printed by hv sops, then:
hv sops -p myapp
hv deploy myapp --env dev --dry-run
hv deploy myapp --env dev
hv status myapp
```

For production, `hv sops -p myapp --env prod` uses `.env.secret.prod` and writes
`secrets/values.prod.enc.yaml`. Dev uses `.env.secret` and
`secrets/values.dev.enc.yaml`. Environments do not borrow each other's files.
Only encrypted `secrets/*.enc.yaml` files are tracked.

## Input and updates

Use `KEY=value` assignments. Values are strings: `false` and `123` remain
strings. Single and double quotes are supported, including quoted multiline
values. Double quotes support `\n`, `\r`, `\t`, `\"`, and `\\` escapes. Shell
variables, backticks, and `$()` are literal and are never executed. Duplicate
keys, invalid names, NULs, and malformed quoted values are rejected.

`hv sops` wraps assignments in a `secret` mapping, creates a missing project
`.sops.yaml` from the current public recipient, and preserves existing rules.
For an existing encrypted file it merges assignments: mentioned keys overwrite,
new keys are added, and unmentioned keys are retained. The output is encrypted
and verified before an atomic replacement. A failed update retains the old file.
Only counts and paths are logged. No plaintext YAML intermediary is written.

The plaintext dotenv file is retained for manual editing and is not read during
deployment. To delete a key, edit the encrypted file with `sops edit` and remove
that key from the dotenv input too, so the next import does not add it back.

The generic command checks formats, not application-specific required fields.
Projects define their own requirements in their deployment scripts or charts.
The supplied Secret templates generate all fields in `.Values.secret`, so new
variables do not require adding a template entry. Containers referencing that
Secret receive the new fields; checksums trigger the relevant Pod rollouts.

## Optional SOPS during deployment

Each supplied project script checks exactly `secrets/values.<env>.enc.yaml`:

- Present: decrypt, validate, and pass values to Helm through stdin.
- Absent: skip SOPS and continue with the project's own checks.
- Present but invalid or undecryptable: stop before invoking Helm.
- Explicit `--secrets-file` path missing: report an error.

The new generic project template works without secrets or SOPS installed.
Applications that require credentials should call `project_deploy_require_secrets`
with their required field names before deploying. Do not pass secrets with `--set`.

Values precedence is base values, optional environment values, extra `--values`
files, SOPS values, then non-secret `--set` overrides. `--values` paths are relative
to the chart; `--secrets-file` paths are relative to the project directory.

Helm release history still stores decrypted values and the rendered Kubernetes
Secret. SOPS protects the repository copy. Changing a database password in a
Secret does not change the password of an account in an existing database.
