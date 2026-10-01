# HelmVerse

[繁體中文](README.md) | English

Use one Bash CLI to set up a **Docker → kind → Kubernetes → Helm** deployment environment on an Ubuntu host. Deploy the included Nginx example to verify the environment, then add your own application, domain, and HTTPS.

The current CLI version is `0.2.0`. HelmVerse is primarily intended for development and testing on a single host.

## Start here

1. [Prepare the host and clone the repository](#1-prepare-the-host-and-clone-the-repository)
2. [Initialize and install tools](#2-initialize-and-install-tools)
3. [Set the host path and create the cluster](#3-set-the-host-path-and-create-the-cluster)
4. [Deploy your first HTTP example](#4-deploy-your-first-http-example)
5. [Optional: add a public domain and HTTPS](#5-optional-add-a-public-domain-and-https)

After step 4, you should see the Nginx `Welcome to nginx!` page. Local verification requires no domain, DNS, Cloudflare, TLS certificate, or application secrets.

## 1. Prepare the host and clone the repository

This guide uses **Ubuntu Linux x86_64 / amd64, Bash, and a regular user account with sudo access**. The included kubectl installer downloads the Linux amd64 build; on an ARM host, install the appropriate tools yourself before continuing. Windows users should run these commands on the Ubuntu deployment host, for example over SSH.

The host must be able to download packages, tools, and container images. TCP ports 80 and 443 must be available for kind and must not already be in use by other services.

```bash
sudo apt-get update
sudo apt-get install -y git curl ca-certificates python3 openssl tar gzip

git clone https://github.com/meatballyun/HelmVerse.git
cd HelmVerse

chmod +x bin/hv
find bin scripts utils projects/my-project -type f -name '*.sh' -exec chmod +x {} +
export PATH="$(pwd -P)/bin:$HOME/.local/bin:$PATH"
hv version
```

Replace the clone URL if you are using a fork. Download the project with `git clone`; some installation scripts require Git repository information. Run all subsequent commands from the HelmVerse root directory in the same shell.

`export PATH` only affects the current shell. After reconnecting, enter the repository and run that line again to make `hv` available.

## 2. Initialize and install tools

For the first installation, generate the version settings used by the installers from `config.json`, then install any missing Docker, kubectl, kind, and Helm tools:

```bash
./scripts/helmverse/generate_envfile.sh
hv init --install-tools -y
```

`generate_envfile.sh` rebuilds the root `.env` file; inspect it first if you already have custom settings. Running `hv init` alone only creates CLI defaults. It does not install required tools or add the `*_VERSION` settings needed by the installers.

**A new Docker installation may stop with `permission denied`.** After the installer adds your user to the docker group, the new permissions do not apply to your current shell yet. If this happens, run:

```bash
newgrp docker
# In the new shell, return to the HelmVerse root directory.
export PATH="$(pwd -P)/bin:$HOME/.local/bin:$PATH"
hv init --install-tools -y
```

Alternatively, log out and back in, return to the repository, set PATH, and rerun the installation. Continue as your original regular user; avoid using `sudo hv`, which would create a separate configuration.

Check the required tools and Docker permissions:

```bash
docker info
kubectl version --client
kind --version
helm version
```

Continue once all commands succeed. K9s, direnv, and SOPS are optional and are not needed for your first HTTP deployment.

## 3. Set the host path and create the cluster

In `config/kind-config.yaml`, `extraMounts.hostPath` must point to the absolute path of `projects/` **on this Ubuntu host**. Get that path first:

```bash
realpath projects
```

Edit `config/kind-config.yaml` in a text editor and replace `hostPath` with the output above. For example:

```yaml
extraMounts:
  - hostPath: /absolute/path/to/HelmVerse/projects
    containerPath: /projects
    propagation: Bidirectional
```

Preserve the file's existing YAML indentation. Do not use `/absolute/path/...` literally. You can keep the defaults for `name: helmverse`, the Pod subnet, and the Service subnet. If either subnet conflicts with your existing network, change it before creating the cluster.

```bash
hv cluster up
kubectl config use-context kind-helmverse
hv cluster addon install ingress
kubectl wait --for=jsonpath='{.webhooks[0].clientConfig.caBundle}' \
  validatingwebhookconfiguration/ingress-nginx-admission --timeout=180s
hv cluster status
```

The node should be `Ready`, and the `ingress-nginx-controller` Pod should be `Running` and Ready. Downloading images and starting the cluster may take a few minutes.

The installer waits for the controller to become available. The [kubectl wait](https://kubernetes.io/docs/reference/kubectl/generated/kubectl_wait/) command above also waits for the admission webhook's CA configuration, helping prevent a temporary webhook error when creating your first Ingress.

kind maps host ports 80 and 443 to the control-plane container, and NGINX Ingress routes requests to your application. Check the mount path again if you move the repository; editing the YAML does not change an existing cluster.

## 4. Deploy your first HTTP example

```bash
hv project create hello --host hello.example.test
hv project validate hello --env dev
hv deploy hello --env dev
hv status hello --no-http

curl -i -H 'Host: hello.example.test' http://127.0.0.1
```

Run the last command **on the Ubuntu deployment host**. You should see `HTTP/1.1 200 OK` and `Welcome to nginx!`. The Host header matches the Ingress rule, so this step does not require DNS. Opening `http://127.0.0.1` directly may return an Ingress 404.

To view the page in a browser on another computer, add a hosts-file entry on that computer mapping `hello.example.test` to a reachable IP address of your Ubuntu host. Then open `http://hello.example.test` and make sure the network allows TCP port 80.

This workflow creates:

- `projects/hello/`: A Helm chart and configuration copied from `my-project`.
- A `hello` namespace and Helm release.
- An Nginx Deployment, Service, and HTTP Ingress.

The dev example does not enable TLS, so `hv status hello --no-http` skips the command's public HTTPS check. At this stage, `hv doctor` may still report failures because the test hostname has no DNS or HTTPS. Use the HTTP verification above to confirm this deployment.

## 5. Optional: add a public domain and HTTPS

After completing the local example, prepare:

- A real domain you control. Replace the `app.example.com` placeholder below.
- A DNS A record pointing to the host's reachable public IPv4 address. If you configure an AAAA record, that address must also be reachable.
- A firewall allowing TCP ports 80 and 443. If the host is behind a router, forward both ports to its fixed private IP address.
- An email address for certificate notifications. HTTP-01 validation requires an HTTP path reachable from the internet.

```bash
# Replace the email address and domain with your own values.
hv cert setup --email admin@example.com
hv project create myapp --host app.example.com
hv project validate myapp --env prod
hv deploy myapp --env prod
hv cert status myapp
```

Wait until the Certificate's `READY` status is `True`, then verify:

```bash
curl -I https://app.example.com
hv status myapp
hv doctor --domain app.example.com
```

The prod example enables two replicas and uses the `letsencrypt-prod` ClusterIssuer and TLS settings in the chart. A successful Helm deployment does not mean the certificate has finished issuing. Here, `prod` is a configuration name; adjust the resource settings for your application.

Cloudflare is an optional DNS and proxy service. If you use its proxy, verify that HTTP, HTTPS, and certificates work on the origin host first, then check the proxy settings.

## Deploy your own application

Edit `projects/<project>/helm-chart/`:

| File / field | Purpose |
| --- | --- |
| `image.repository` and `image.tag` in `values.yaml` | Set your application image; use a tested, fixed version for public deployments |
| `service.port` and `service.targetPort` | The Service port and the port your container actually listens on |
| `values.dev.yaml` and `values.prod.yaml` | Environment differences such as replicas, resources, and TLS |
| `configmap.data` | Non-secret environment variables; enable `configmap.enabled` first |
| `persistence` and `templates/deployment.yaml` | Adjust the PVC, mount path, and access mode for your application |
| `templates/` | Project-specific Kubernetes resources, such as multiple services or databases |

After editing, run `hv project validate <project> --env dev` before deploying. `hv deploy` calls the project's `helm-chart/deploy.sh`; it does not automatically clone source code or build your application image.

The example script defaults to `dev`. `project.env` contains metadata; changing its `DEPLOY_ENV` does not change this default. Pass `--env prod` explicitly. The dev and prod environments of the same project share a release and namespace, so switching environments updates the same deployment. To run both at once, use different project names and hostnames.

See the [example project guide](projects/my-project/README.en.md) for more settings.

## Optional: manage secrets with SOPS

The Nginx example does not need secrets. If your application uses passwords or API tokens:

```bash
hv sops init
hv sops -p myapp --env prod
# Edit projects/myapp/.env.secret.prod as prompted, adding the KEY=value entries your application needs.
hv sops -p myapp --env prod
hv project validate myapp --env prod
hv deploy myapp --env prod
```

The first preparation command only creates the local input file. Fill it in, then run the command again to encrypt it. `.sops.yaml` is generated automatically using the current user's age public key; you do not need to copy another project's settings.

| Environment | Plaintext input, kept local | Encrypted output you can commit |
| --- | --- | --- |
| dev | `.env.secret` | `secrets/values.dev.enc.yaml` |
| prod | `.env.secret.prod` | `secrets/values.prod.enc.yaml` |

Keep a backup of your age private key. Do not commit private keys, plaintext dotenv files, or secret values to Git, and do not pass secrets through `--set`. SOPS protects the copies in the repository; Helm and Kubernetes still hold decrypted deployment data. See the [SOPS guide](docs/sops.md) for details.

## Everyday commands

| Command | Purpose |
| --- | --- |
| `hv project list` / `hv project show myapp` | View projects and settings |
| `hv status myapp --no-http` | View the release, Pods, Services, and Ingress |
| `hv logs --project myapp` | View application logs |
| `hv shell --project myapp` | Open a shell in a Pod |
| `hv rollback myapp` | Restore the previous Helm revision |
| `hv cert status myapp` | View TLS certificates |
| `hv cluster status` | View the cluster and Pods |
| `hv <command> --help` | Show all available options |

Optional tools: `hv init --with-k9s` installs K9s, and `hv k9s --namespace myapp --readonly` opens its read-only interface. To use direnv, first run `sudo apt-get install -y direnv`, then `hv init --configure-shell` and reload your shell as instructed.

## Troubleshooting

| Symptom | What to do |
| --- | --- |
| `hv: command not found` | Return to the repository and repeat the PATH setup in step 1, or use `./bin/hv` |
| `Permission denied` / `Unknown command` | Check script execution permissions and rerun the `chmod` commands in step 1 |
| Installer reports `*_VERSION: unbound variable` | Generate `.env` from `config.json` as described in step 2, then rerun the installation |
| Docker socket permission error | Log in again or run `newgrp docker`, then confirm that `docker info` succeeds |
| `port is already allocated` | Use `sudo ss -lntp` to identify services using ports 80 or 443, then resolve the conflict |
| Ingress admission webhook connection failure | Confirm that the controller is Ready, rerun the webhook wait command in step 3, then deploy again |
| HTTP 404 | Check that the request's Host header or domain matches the Ingress host |
| HTTP 502 / 503 or deployment timeout | Use `kubectl get pods -n myapp`, `kubectl describe pod -n myapp <pod>`, and logs to check the image, ports, probes, and resources |
| Certificate remains Pending | Check DNS, the firewall, TCP ports 80 and 443, `hv cert status myapp`, and `kubectl describe certificate -n myapp` |
| `hv doctor` fails during initial setup | It also checks the cluster, ports, DNS, and HTTPS. Some failures are expected before tools are installed or when only local HTTP is configured |

## Remove the example and environment

```bash
hv undeploy hello
```

This removes the Helm release and keeps the namespace. If you no longer need the PVCs, Secrets, and other resources in that namespace, use `hv undeploy hello --purge-namespace`. `hv cluster down` deletes the entire kind cluster and its workloads; back up any data you need before running it.

## Repository structure

```text
bin/hv                    CLI entry point
bin/commands/             Subcommands
config/kind-config.yaml   Cluster name, host mounts, and port settings
config.json               CLI and tool version settings
projects/my-project/      Template for new projects
projects/<project>/       Your deployment chart and environment settings
scripts/                  Tool installers, cluster scripts, and add-ons
utils/                    Shared deployment and SOPS functions
docs/sops.md              Detailed SOPS workflow
```

`scripts/docker-compose/` and `scripts/gitops/` are retained for standalone or legacy workflows. They are not required for the quick start above.
