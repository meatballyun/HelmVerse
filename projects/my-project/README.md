# HelmVerse 專案範例

繁體中文 | [English](README.en.md)

`my-project` 是 `hv project create` 使用的模板。它提供 Nginx Deployment、Service、Ingress、可選的 PVC、ConfigMap 與 Secret，供新專案複製及修改。

## 目錄

```text
my-project/
├── .env.secret.example       # 秘密變數的填寫範例，只有註解
├── .gitignore
├── .sops.yaml.example        # 加密規則說明，不會自動套用
├── project.env              # 專案與來源 repository 的 metadata
└── helm-chart/
    ├── Chart.yaml
    ├── deploy.sh            # hv deploy / hv project validate 的入口
    ├── values.yaml          # 共用的非機密設定
    ├── values.dev.yaml      # 開發環境覆寫
    ├── values.prod.yaml     # 正式環境覆寫範例
    └── templates/           # Deployment、Service、Ingress、PVC、ConfigMap、Secret
```

## 建立與部署

在 HelmVerse 根目錄執行；若尚未設定 `hv` 的 PATH，可使用 `./bin/hv`。

```bash
hv project create myapp --host myapp.example.com
hv project validate myapp --env dev
hv deploy myapp --env dev
hv status myapp --no-http
```

驗證需要 Helm 3；實際部署還需要已啟動的 kind cluster、可用的 kubectl，以及對應的 Ingress controller。請先依 [HelmVerse README](../../README.md) 初始化環境。`myapp.example.com` 是佔位網域，請換成自己的網域並設定 DNS。

新專案會取得模板副本。建立後編輯 `projects/myapp/helm-chart/` 的 values 檔案；共用的 hostname 會由 `--host` 填入。預設使用 Nginx image，可自行改成應用程式 image。若應用程式監聽其他連接埠，請同步檢查 `service.port` 與 `service.targetPort`。

移除部署：

```bash
hv undeploy myapp
```

## dev / prod 設定

部署依序載入 `values.yaml`、`values.<env>.yaml`、額外 `--values`、SOPS 秘密，最後套用非機密的 `--set`。

- `dev`：一個 replica，較小的資源額度，停用 Ingress TLS。
- `prod`：兩個 replicas，較大的資源額度，使用共用 values 中的 TLS hosts 與 `letsencrypt-prod` ClusterIssuer。部署前須完成 cert-manager 與 issuer 設定。
- 資源額度只是示例，請依應用程式調整；正式部署也應將 image tag 換成已驗證的固定版本。

```bash
hv project validate myapp --env prod
hv deploy myapp --env prod
```

`--env` 選擇 values 與秘密檔案。範例部署腳本預設為 `dev`，不會讀取 `project.env` 的 `DEPLOY_ENV`。同一專案的 dev/prod 使用相同 Helm release 與 namespace；切換環境會更新同一份部署。需要兩套並存時，請建立不同的專案名稱與 hostname。

## 非機密環境變數與儲存

啟用 `configmap.enabled` 並修改 `configmap.data`，即可將非機密設定注入容器。秘密請使用下方的 SOPS 流程。

啟用 `persistence.enabled` 可掛載 PVC 到 Nginx 的 `/usr/share/nginx/html`；請依應用程式修改掛載路徑、容量與 StorageClass。多個 replicas 共用 PVC 前，需確認儲存系統支援所需的存取模式。

## 可選的 SOPS 秘密

Nginx 範例不需要秘密；沒有加密 values 時，部署會略過 SOPS。應用程式需要秘密時：

```bash
hv sops init
hv sops -p myapp --env dev
# 編輯命令顯示的 projects/myapp/.env.secret：取消所需範例的註解並填入自己的值。
hv sops -p myapp --env dev
hv project validate myapp --env dev
hv deploy myapp --env dev
```

第一次 `hv sops -p myapp` 只建立 `.env.secret`；填寫後再次執行才會加密。若缺少 `.sops.yaml`，工具會使用目前使用者的 age 公鑰自動建立規則。`.sops.yaml.example` 僅供閱讀，正常流程不需複製或更名，也不要沿用其他專案的 recipient。

| 環境 | 本機明文輸入，Git 忽略 | 加密輸出，可提交 |
| --- | --- | --- |
| dev | `.env.secret` | `secrets/values.dev.enc.yaml` |
| prod | `.env.secret.prod` | `secrets/values.prod.enc.yaml` |

正式環境使用 `hv sops -p myapp --env prod`，同樣先建立輸入、填寫，再重新執行。兩個環境不會互相借用秘密檔。

秘密會注入 `.Values.secret`，由 `templates/secret.yaml` 產生 Kubernetes Secret，再以 `envFrom` 傳入容器。秘密變更會更新 Deployment checksum，觸發 Pod rollout。變數名稱由應用程式決定；預設 Nginx 不會使用這些應用程式變數。

請保持 `values.yaml` 的 `secret: {}` 為空，不要將秘密寫入 values、`project.env` 或 `--set`。`.env.secret*` 與 age 私鑰只留在本機；可提交產生的 `.sops.yaml` 公鑰設定與加密輸出。SOPS 保護 repository 中的副本，Helm release history 與 Kubernetes 仍會持有解密後的值。完整流程見 [SOPS 說明](../../docs/sops.md)。
