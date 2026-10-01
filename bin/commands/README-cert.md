# Certificate Management Command (hv cert)

完全重寫的證書管理命令，支援完整的參數輸入和 namespace 指定。

## 主要功能

1. **安裝 cert-manager** - 一鍵安裝 cert-manager
2. **建立 ClusterIssuer** - 為 Let's Encrypt 建立 ClusterIssuer
3. **建立 Certificate** - 在指定的 namespace 建立 TLS 證書
4. **建立 Ingress** - 建立帶 TLS 的 Ingress 資源
5. **一鍵建立** - 同時建立 Certificate 和 Ingress
6. **刪除資源** - 刪除 Certificate 或 ClusterIssuer
7. **查看狀態** - 查看所有證書和 issuer 的狀態

## 重要特性

### ✅ 完全參數化
- 所有參數都可以透過命令列指定
- 不再有硬編碼的域名或 email
- 支援自訂所有資源名稱

### ✅ Namespace 支援
- **可以指定 TLS secret 建立在任何 namespace**
- 預設使用 `default` namespace（而非 `ingress-nginx`）
- Ingress 和 Certificate 可以在同一個 namespace

### ✅ 自動化功能
- `--auto-install`: 自動安裝 cert-manager（如果未安裝）
- `--email`: 自動建立 ClusterIssuer（如果不存在）
- `create-full`: 一個命令同時建立 Certificate 和 Ingress

## 使用範例

### 1. 完整工作流程

```bash
# 步驟 1: 安裝 cert-manager
hv cert install

# 步驟 2: 建立 ClusterIssuer
hv cert create-issuer --email admin@example.com

# 步驟 3: 建立 Certificate（TLS secret 會建立在指定的 namespace）
hv cert create-cert \
  --domain myapp.example.com \
  --namespace production \
  --email admin@example.com

# 步驟 4: 建立 Ingress（使用同一個 namespace 的 TLS secret）
hv cert create-ingress \
  --domain myapp.example.com \
  --service myapp-svc \
  --port 8080 \
  --namespace production
```

### 2. 一鍵建立（推薦）

最簡單的方式 - 一個命令完成所有設定：

```bash
hv cert create-full \
  --domain myapp.example.com \
  --service myapp-svc \
  --port 8080 \
  --namespace production \
  --email admin@example.com
```

這個命令會：
- 自動安裝 cert-manager（如果需要）
- 建立 ClusterIssuer（如果不存在）
- 在 `production` namespace 建立 Certificate 和 TLS secret
- 在 `production` namespace 建立 Ingress

### 3. 多個應用在不同 namespace

```bash
# 應用 1 - 在 frontend namespace
hv cert create-full \
  --domain frontend.example.com \
  --service frontend-svc \
  --port 3000 \
  --namespace frontend \
  --email admin@example.com

# 應用 2 - 在 backend namespace
hv cert create-full \
  --domain api.example.com \
  --service backend-svc \
  --port 8080 \
  --namespace backend \
  --email admin@example.com

# 應用 3 - 在 default namespace
hv cert create-full \
  --domain admin.example.com \
  --service admin-svc \
  --port 5000 \
  --email admin@example.com
```

### 4. 使用測試環境（Staging）

```bash
# 使用 Let's Encrypt staging server（避免 rate limit）
hv cert create-issuer --email admin@example.com --staging

hv cert create-cert \
  --domain test.example.com \
  --namespace test \
  --issuer-name letsencrypt-staging \
  --email admin@example.com
```

### 5. 自訂資源名稱

```bash
hv cert create-cert \
  --domain myapp.example.com \
  --namespace production \
  --cert-name my-custom-cert \
  --secret-name my-custom-tls-secret \
  --email admin@example.com
```

### 6. 帶自訂 annotations 的 Ingress

```bash
hv cert create-ingress \
  --domain myapp.example.com \
  --service myapp-svc \
  --port 8080 \
  --namespace production \
  --annotations "nginx.ingress.kubernetes.io/rewrite-target=/,nginx.ingress.kubernetes.io/ssl-redirect=true,nginx.ingress.kubernetes.io/proxy-body-size=10m"
```

### 7. API 路徑路由

```bash
hv cert create-full \
  --domain api.example.com \
  --service api-svc \
  --port 3000 \
  --namespace backend \
  --path /api \
  --email admin@example.com
```

## 命令參考

### `hv cert install`
安裝 cert-manager 到集群。

### `hv cert create-issuer`
建立 ClusterIssuer。

**選項：**
- `--email <email>` (必填): Let's Encrypt 通知 email
- `--issuer-name <name>`: ClusterIssuer 名稱（預設: letsencrypt-prod）
- `--server <url>`: ACME server URL
- `--ingress-class <class>`: Ingress class（預設: nginx）
- `--staging`: 使用 Let's Encrypt staging server

### `hv cert create-cert`
建立 Certificate 資源。

**選項：**
- `--domain <domain>` (必填): 域名
- `--namespace <namespace>`: TLS secret 的 namespace（預設: default）
- `--cert-name <name>`: Certificate 資源名稱
- `--secret-name <name>`: TLS secret 名稱
- `--issuer-name <name>`: ClusterIssuer 名稱（預設: letsencrypt-prod）
- `--email <email>`: Let's Encrypt email（會自動建立 issuer）
- `--auto-install`: 自動安裝 cert-manager

### `hv cert create-ingress`
建立 Ingress 資源。

**選項：**
- `--domain <domain>` (必填): 域名
- `--service <service>` (必填): 後端服務名稱
- `--port <port>` (必填): 後端服務 port
- `--namespace <namespace>`: Ingress 的 namespace（預設: default）
- `--name <name>`: Ingress 資源名稱
- `--path <path>`: 路徑（預設: /）
- `--path-type <type>`: 路徑類型（預設: Prefix）
- `--secret-name <name>`: TLS secret 名稱
- `--issuer-name <issuer>`: ClusterIssuer 名稱
- `--annotations <annot>`: 額外的 annotations

### `hv cert create-full`
一次建立 Certificate 和 Ingress。

**選項：**
- `--domain <domain>` (必填): 域名
- `--service <service>` (必填): 後端服務名稱
- `--port <port>` (必填): 後端服務 port
- `--email <email>` (必填): Let's Encrypt email
- `--namespace <namespace>`: 資源的 namespace（預設: default）
- `--issuer-name <issuer>`: ClusterIssuer 名稱
- `--path <path>`: 路徑（預設: /）
- `--annotations <annot>`: Ingress annotations

### `hv cert delete-cert`
刪除 Certificate。

**選項：**
- `--name <name>` (必填): Certificate 名稱
- `--namespace <namespace>`: Namespace（預設: default）

### `hv cert delete-issuer`
刪除 ClusterIssuer。

**選項：**
- `--name <name>`: ClusterIssuer 名稱（預設: letsencrypt-prod）

### `hv cert status`
查看所有證書和 issuer 的狀態。

## 重要說明

### Namespace 的使用

**TLS Secret 的位置非常重要！**

- TLS secret 必須和使用它的 Ingress 在**同一個 namespace**
- 使用 `--namespace` 參數指定 TLS secret 的 namespace
- 建議將 Certificate、Ingress 和應用服務都放在同一個 namespace

**範例：**

```bash
# ✅ 正確：Certificate 和 Ingress 在同一個 namespace
hv cert create-cert --domain myapp.com --namespace production --email admin@example.com
hv cert create-ingress --domain myapp.com --service myapp-svc --port 8080 --namespace production

# ❌ 錯誤：Certificate 在 default，Ingress 在 production
hv cert create-cert --domain myapp.com --namespace default --email admin@example.com
hv cert create-ingress --domain myapp.com --service myapp-svc --port 8080 --namespace production
# Ingress 無法找到 TLS secret！
```

### 與舊版的差異

**舊版 (已棄用):**
```bash
hv cert init <subdomain> <service> <port> <email>
# 硬編碼 bumiverse.com 域名
# 固定使用 ingress-nginx namespace
```

**新版 (推薦):**
```bash
hv cert create-full \
  --domain <完整域名> \
  --service <service> \
  --port <port> \
  --namespace <namespace> \
  --email <email>
# 完全自訂所有參數
# 可指定任何 namespace
```

## 故障排除

### 查看證書狀態

```bash
# 查看所有資源
hv cert status

# 查看特定 Certificate
kubectl describe certificate <cert-name> -n <namespace>

# 查看 Certificate Request
kubectl get certificaterequest -n <namespace>

# 查看 TLS Secret
kubectl get secret <secret-name> -n <namespace>
```

### 常見問題

1. **Certificate 卡在 Pending**
   - 檢查域名是否可公開訪問
   - 檢查 Ingress Controller 是否正常運行
   - 查看 cert-manager logs: `kubectl logs -n cert-manager deployment/cert-manager`

2. **Ingress 無法使用 TLS**
   - 確認 TLS secret 和 Ingress 在同一個 namespace
   - 檢查 secret 是否已建立: `kubectl get secret -n <namespace>`

3. **Let's Encrypt Rate Limit**
   - 使用 `--staging` 選項進行測試
   - Staging server 沒有 rate limit

## 最佳實踐

1. **使用 `create-full` 命令** - 最簡單且不易出錯
2. **測試時使用 staging** - 避免觸發 Let's Encrypt rate limit
3. **統一 namespace** - 將相關資源放在同一個 namespace
4. **命名規範** - 使用有意義的資源名稱
5. **定期檢查狀態** - 使用 `hv cert status` 監控證書狀態

## 完整範例：部署新應用

```bash
# 1. 部署應用
kubectl create namespace myapp
kubectl create deployment myapp --image=myapp:latest -n myapp
kubectl expose deployment myapp --port=8080 -n myapp

# 2. 建立證書和 Ingress（一個命令）
hv cert create-full \
  --domain myapp.example.com \
  --service myapp \
  --port 8080 \
  --namespace myapp \
  --email admin@example.com

# 3. 檢查狀態
hv cert status

# 4. 測試訪問
curl https://myapp.example.com
```

完成！現在你的應用已經有了 HTTPS 支援。
