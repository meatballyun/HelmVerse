# HelmVerse Example Project

[繁體中文](README.md) | English

`my-project` is the template used by `hv project create`. It provides an Nginx Deployment, Service, Ingress, and optional PVC, ConfigMap, and Secret for new projects to copy and customize.

## Directory structure

```text
my-project/
├── .env.secret.example       # Commented examples of secret variables
├── .gitignore
├── .sops.yaml.example        # Encryption rule reference; not applied automatically
├── project.env              # Project and source repository metadata
└── helm-chart/
    ├── Chart.yaml
    ├── deploy.sh            # Entry point for hv deploy / hv project validate
    ├── values.yaml          # Shared non-secret settings
    ├── values.dev.yaml      # Development overrides
    ├── values.prod.yaml     # Example production overrides
    └── templates/           # Deployment, Service, Ingress, PVC, ConfigMap, Secret
```

## Create and deploy

Run these commands from the HelmVerse root directory. If `hv` is not on your PATH yet, use `./bin/hv`.

```bash
hv project create myapp --host myapp.example.com
hv project validate myapp --env dev
hv deploy myapp --env dev
hv status myapp --no-http
```

Validation requires Helm 3. Deployment also requires a running kind cluster, a working kubectl installation, and the corresponding Ingress controller. Initialize your environment using the [HelmVerse quick start](../../README.en.md) first. `myapp.example.com` is a placeholder; replace it with your own domain and configure DNS.

New projects receive a copy of this template. After creation, edit the values files in `projects/myapp/helm-chart/`; `--host` sets the shared hostname. The default image is Nginx, which you can replace with your application image. If your application listens on a different port, also check `service.port` and `service.targetPort`.

Remove the deployment:

```bash
hv undeploy myapp
```

## dev / prod settings

Deployment loads `values.yaml`, `values.<env>.yaml`, additional `--values` files, and SOPS secrets in that order, then applies non-secret `--set` overrides.

- `dev`: One replica, smaller resource allocations, and Ingress TLS disabled.
- `prod`: Two replicas, larger resource allocations, and the TLS hosts and `letsencrypt-prod` ClusterIssuer from the shared values. Configure cert-manager and the issuer before deploying.
- Resource allocations are examples; adjust them for your application. For production, also replace the image tag with a tested, fixed version.

```bash
hv project validate myapp --env prod
hv deploy myapp --env prod
```

`--env` selects the values and secrets files. The example deployment script defaults to `dev` and does not read `DEPLOY_ENV` from `project.env`. The dev and prod environments of the same project share a Helm release and namespace; switching environments updates the same deployment. To run both at once, create projects with different names and hostnames.

## Non-secret environment variables and storage

Enable `configmap.enabled` and edit `configmap.data` to inject non-secret settings into the container. Use the SOPS workflow below for secrets.

Enable `persistence.enabled` to mount a PVC at Nginx's `/usr/share/nginx/html`. Adjust the mount path, capacity, and StorageClass for your application. Before sharing a PVC across multiple replicas, confirm that your storage system supports the required access mode.

## Optional SOPS secrets

The Nginx example does not require secrets. Deployment skips SOPS when there are no encrypted values. If your application needs secrets:

```bash
hv sops init
hv sops -p myapp --env dev
# Edit projects/myapp/.env.secret as shown by the command: uncomment the examples you need and enter your own values.
hv sops -p myapp --env dev
hv project validate myapp --env dev
hv deploy myapp --env dev
```

The first `hv sops -p myapp` only creates `.env.secret`; fill it in, then run the command again to encrypt it. If `.sops.yaml` is missing, the tool automatically creates rules using the current user's age public key. `.sops.yaml.example` is a reference file. You do not need to copy or rename it for the standard workflow, and you should not reuse another project's recipient.

| Environment | Local plaintext input, ignored by Git | Encrypted output, safe to commit |
| --- | --- | --- |
| dev | `.env.secret` | `secrets/values.dev.enc.yaml` |
| prod | `.env.secret.prod` | `secrets/values.prod.enc.yaml` |

For production, use `hv sops -p myapp --env prod`: create the input file, fill it in, then run the command again. Neither environment falls back to the other's secrets file.

Secrets are injected into `.Values.secret`. `templates/secret.yaml` creates a Kubernetes Secret, which is passed to the container through `envFrom`. Secret changes update the Deployment checksum and trigger a Pod rollout. Your application determines the variable names; the default Nginx image does not use these application variables.

Keep `secret: {}` empty in `values.yaml`. Do not put secrets in values files, `project.env`, or `--set`. Keep `.env.secret*` and your age private key local; you may commit the generated `.sops.yaml` public-key configuration and encrypted output. SOPS protects the copies in your repository, while Helm release history and Kubernetes still hold the decrypted values. See the [SOPS guide](../../docs/sops.md) for the complete workflow.
