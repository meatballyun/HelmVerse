apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: {{ .IssuerName }}
spec:
  acme:
    email: {{ .Email }}
    server: {{ .Server }}
    privateKeySecretRef:
      name: {{ .IssuerName }}
    solvers:
      - http01:
          ingress:
            class: {{ .IngressClass }}