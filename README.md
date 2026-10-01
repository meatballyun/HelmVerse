# HelmVerse

繁體中文 | [English](README.en.md)

用一套 Bash CLI，在 Ubuntu 主機上建立 **Docker → kind → Kubernetes → Helm** 部署環境。先部署內附的 Nginx 範例確認環境，再接上自己的應用程式、網域與 HTTPS。

目前 CLI 版本為 `0.2.0`。主要使用情境是單機開發與測試環境。

## 從這裡開始

1. [準備主機與下載專案](#1-準備主機與下載專案)
2. [初始化與安裝工具](#2-初始化與安裝工具)
3. [設定主機路徑並建立-cluster](#3-設定主機路徑並建立-cluster)
4. [部署第一個-http-範例](#4-部署第一個-http-範例)
5. [選用公開網域與-https](#5-選用公開網域與-https)

完成第 4 步後，應能看到 Nginx 的 `Welcome to nginx!` 頁面。本機驗證不需要網域、DNS、Cloudflare、TLS 憑證或應用程式秘密。

## 1. 準備主機與下載專案

本指南使用 **Ubuntu Linux x86_64 / amd64、Bash、可使用 sudo 的一般使用者帳號**。目前內附的 kubectl 安裝腳本固定下載 Linux amd64 版本；ARM 主機請自行安裝對應工具後再繼續。Windows 使用者請在準備部署的 Ubuntu 主機上執行以下命令，例如透過 SSH。

主機需要能下載套件、工具與容器映像。TCP 80、443 必須可供 kind 使用，不能已被其他服務占用。

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

若使用 fork，請替換 clone URL。請透過 `git clone` 下載；部分安裝腳本需要 Git repository 資訊。後續命令都從 HelmVerse 根目錄執行，並沿用同一個 shell。

`export PATH` 僅影響目前 shell。之後重新連線時，進入 repo 並再次執行該行，即可使用 `hv`。

## 2. 初始化與安裝工具

第一次安裝時，先從 `config.json` 產生安裝器使用的版本設定，再安裝缺少的 Docker、kubectl、kind 與 Helm：

```bash
./scripts/helmverse/generate_envfile.sh
hv init --install-tools -y
```

`generate_envfile.sh` 會重建根目錄 `.env`；已有自訂設定時，請先檢查該檔案。單獨執行 `hv init` 只建立 CLI 預設值，不會安裝必要工具，也不會補上安裝器需要的 `*_VERSION`。

**剛安裝 Docker 時，可能停在 `permission denied`。** 安裝器加入 docker 群組後，新權限尚未套用到目前 shell。若遇到這個情況，執行：

```bash
newgrp docker
# 進入新 shell 後，回到 HelmVerse 根目錄。
export PATH="$(pwd -P)/bin:$HOME/.local/bin:$PATH"
hv init --install-tools -y
```

也可以登出後重新登入，再回到 repo、設定 PATH 並重跑安裝。請用原本的一般使用者繼續操作，避免使用 `sudo hv` 建立另一套設定。

確認必要工具與 Docker 權限：

```bash
docker info
kubectl version --client
kind --version
helm version
```

以上命令都成功後再繼續。K9s、direnv 與 SOPS 都是選用功能，首次 HTTP 部署不需要安裝。

## 3. 設定主機路徑並建立 cluster

`config/kind-config.yaml` 的 `extraMounts.hostPath` 必須指向**這台 Ubuntu 主機上**的 `projects/` 絕對路徑。先取得路徑：

```bash
realpath projects
```

用文字編輯器修改 `config/kind-config.yaml`，將 `hostPath` 換成上方輸出，例如：

```yaml
extraMounts:
  - hostPath: /absolute/path/to/HelmVerse/projects
    containerPath: /projects
    propagation: Bidirectional
```

保留檔案原有的 YAML 縮排。不要原樣使用 `/absolute/path/...`。`name: helmverse`、Pod subnet 與 Service subnet 可先保留預設值；若子網段與現有網路衝突，請在建立 cluster 前調整。

```bash
hv cluster up
kubectl config use-context kind-helmverse
hv cluster addon install ingress
kubectl wait --for=jsonpath='{.webhooks[0].clientConfig.caBundle}' \
  validatingwebhookconfiguration/ingress-nginx-admission --timeout=180s
hv cluster status
```

預期 node 為 `Ready`，`ingress-nginx-controller` 的 Pod 為 `Running` 且 Ready。下載映像與啟動 cluster 可能需要幾分鐘。

安裝器會等待 controller 可用；上方的 [kubectl wait](https://kubernetes.io/docs/reference/kubectl/generated/kubectl_wait/) 再等待 admission webhook 的 CA 設定完成，避免第一次建立 Ingress 時遇到暫時的 webhook 錯誤。

kind 會將主機的 80、443 映射到 control-plane 容器，再由 NGINX Ingress 將請求導向應用程式。搬移 repo 後需重新檢查掛載路徑；修改 YAML 不會改變已建立的 cluster。

## 4. 部署第一個 HTTP 範例

```bash
hv project create hello --host hello.example.test
hv project validate hello --env dev
hv deploy hello --env dev
hv status hello --no-http

curl -i -H 'Host: hello.example.test' http://127.0.0.1
```

最後一個命令在 **Ubuntu 部署主機上**執行。預期看到 `HTTP/1.1 200 OK` 與 `Welcome to nginx!`。Host header 讓請求符合 Ingress 規則，所以這一步不需要 DNS；直接開啟 `http://127.0.0.1` 可能得到 Ingress 的 404。

若要用另一台電腦的瀏覽器查看，將其 hosts 檔中的 `hello.example.test` 指向 Ubuntu 主機可達的 IP，再開啟 `http://hello.example.test`，並確認網路允許 TCP 80。

這個流程會建立：

- `projects/hello/`：由 `my-project` 複製的 Helm chart 與設定。
- `hello` namespace 與 Helm release。
- Nginx Deployment、Service 與 HTTP Ingress。

dev 範例不啟用 TLS，因此使用 `hv status hello --no-http` 跳過該指令的公開 HTTPS 檢查。此時 `hv doctor` 仍可能因測試 hostname 沒有 DNS／HTTPS 而回報失敗；先以上述 HTTP 驗證結果為準。

## 5. 選用：公開網域與 HTTPS

完成本機範例後，準備：

- 自己控制的真實網域，例如下方的 `app.example.com` 必須替換。
- DNS A record 指向主機可達的公開 IPv4；若設定 AAAA，也必須能正確連線。
- 防火牆允許 TCP 80、443；主機位於路由器後方時，將兩個 port 轉發到固定的主機內網 IP。
- 可接收憑證通知的 Email。HTTP-01 驗證需要外部可達的 HTTP 路徑。

```bash
# 將 Email 和網域替換成自己的值。
hv cert setup --email admin@example.com
hv project create myapp --host app.example.com
hv project validate myapp --env prod
hv deploy myapp --env prod
hv cert status myapp
```

等 Certificate 的 `READY` 為 `True` 後，再確認：

```bash
curl -I https://app.example.com
hv status myapp
hv doctor --domain app.example.com
```

prod 範例啟用兩個 replicas，沿用 `letsencrypt-prod` ClusterIssuer 與 chart 內的 TLS 設定。Helm 部署成功不代表憑證已簽發完成。這裡的 `prod` 是設定檔名稱，資源配置仍需依自己的應用程式調整。

Cloudflare 是選用的 DNS／代理服務。若使用代理，請先確認來源主機的 HTTP、HTTPS 與憑證都能正常工作，再檢查代理設定。

## 部署自己的應用程式

編輯 `projects/<project>/helm-chart/`：

| 檔案／欄位 | 用途 |
| --- | --- |
| `values.yaml` 的 `image.repository`、`image.tag` | 指定應用程式映像；對外部署時使用已驗證的固定版本 |
| `service.port`、`service.targetPort` | Service port 與容器實際監聽的 port |
| `values.dev.yaml`、`values.prod.yaml` | 環境差異，例如 replicas、resources 與 TLS |
| `configmap.data` | 非機密環境變數；先啟用 `configmap.enabled` |
| `persistence` 與 `templates/deployment.yaml` | 依應用程式調整 PVC、掛載路徑與存取模式 |
| `templates/` | 多服務、資料庫等專案專屬的 Kubernetes 資源 |

修改後先執行 `hv project validate <project> --env dev`，再部署。`hv deploy` 會呼叫專案的 `helm-chart/deploy.sh`，不會自動 clone 原始碼或建置應用程式 image。

範例腳本預設使用 `dev`；`project.env` 是 metadata，修改其中的 `DEPLOY_ENV` 不會改變此預設。請明確傳入 `--env prod`。同一專案的 dev/prod 共用 release 與 namespace，切換環境會更新同一個部署；需要並存時請建立不同專案名稱與 hostname。

更多設定見 [專案範例說明](projects/my-project/README.md)。

## 選用：SOPS 秘密管理

Nginx 範例不需要秘密。應用程式有密碼或 API token 時：

```bash
hv sops init
hv sops -p myapp --env prod
# 編輯提示的 projects/myapp/.env.secret.prod，填入應用程式需要的 KEY=value。
hv sops -p myapp --env prod
hv project validate myapp --env prod
hv deploy myapp --env prod
```

第一次準備命令只建立本機輸入；填寫後再次執行才會加密。`.sops.yaml` 會使用目前使用者的 age 公鑰自動產生，不必複製其他專案的設定。

| 環境 | 明文輸入，僅留本機 | 可提交的加密輸出 |
| --- | --- | --- |
| dev | `.env.secret` | `secrets/values.dev.enc.yaml` |
| prod | `.env.secret.prod` | `secrets/values.prod.enc.yaml` |

保留自己的 age 私鑰備份；不要將私鑰、明文 dotenv 或秘密值提交到 Git，也不要透過 `--set` 傳入秘密。SOPS 保護 repository 副本；Helm 與 Kubernetes 仍持有解密後的部署資料。詳見 [SOPS 流程（英文）](docs/sops.md)。

## 日常操作

| 指令 | 用途 |
| --- | --- |
| `hv project list` / `hv project show myapp` | 查看專案與設定 |
| `hv status myapp --no-http` | 查看 release、Pod、Service 與 Ingress |
| `hv logs --project myapp` | 查看應用程式 logs |
| `hv shell --project myapp` | 進入 Pod shell |
| `hv rollback myapp` | 回復上一個 Helm revision |
| `hv cert status myapp` | 查看 TLS 憑證 |
| `hv cluster status` | 查看 cluster 與 Pods |
| `hv <command> --help` | 查看完整參數 |

選用工具：`hv init --with-k9s` 安裝 K9s，`hv k9s --namespace myapp --readonly` 啟動唯讀介面。若要使用 direnv，可先 `sudo apt-get install -y direnv`，再執行 `hv init --configure-shell` 並依提示重新載入 shell。

## 常見問題

| 狀況 | 處理方式 |
| --- | --- |
| `hv: command not found` | 回到 repo 並重新執行第 1 步的 PATH 設定，或使用 `./bin/hv` |
| `Permission denied` / `Unknown command` | 檢查腳本執行權限，重跑第 1 步的 `chmod` 命令 |
| 安裝器出現 `*_VERSION: unbound variable` | 依第 2 步從 `config.json` 產生 `.env`，再重跑安裝 |
| Docker socket 權限不足 | 重新登入或 `newgrp docker`，確認 `docker info` 成功 |
| `port is already allocated` | 用 `sudo ss -lntp` 找出占用 80／443 的服務，先解決 port 衝突 |
| Ingress admission webhook 連線失敗 | 確認 controller Ready，重跑第 3 步的 webhook 等待命令後再部署 |
| HTTP 404 | 確認請求 Host header／網域與 Ingress host 一致 |
| HTTP 502／503 或部署 timeout | 用 `kubectl get pods -n myapp`、`kubectl describe pod -n myapp <pod>` 與 logs 檢查 image、port、probes 和資源 |
| 憑證一直 Pending | 檢查 DNS、防火牆、TCP 80／443、`hv cert status myapp` 與 `kubectl describe certificate -n myapp` |
| `hv doctor` 在初期失敗 | 它也檢查 cluster、ports、DNS 與 HTTPS；工具尚未安裝或只完成本機 HTTP 時，部分失敗是預期的 |

## 移除範例與環境

```bash
hv undeploy hello
```

這會移除 Helm release，保留 namespace。若確定不要 namespace 內的 PVC、Secret 與其他資源，可使用 `hv undeploy hello --purge-namespace`。`hv cluster down` 會刪除整個 kind cluster 與其中的工作負載，執行前請先備份需要保留的資料。

## 專案結構

```text
bin/hv                    CLI 入口
bin/commands/             子命令
config/kind-config.yaml   cluster 名稱、主機掛載與 port 設定
config.json               CLI 與工具版本設定
projects/my-project/      建立新專案的模板
projects/<project>/       自己的部署 chart 與環境設定
scripts/                  工具安裝、cluster 與 add-on 腳本
utils/                    共用部署與 SOPS 函式
docs/sops.md              SOPS 詳細流程
```

`scripts/docker-compose/` 與 `scripts/gitops/` 保留供獨立或舊版流程使用，不是上述快速開始的必要步驟。
