apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: {{ .CertName }}
  namespace: {{ .Namespace }}
spec:
  secretName: {{ .SecretName }}
  dnsNames:
    - {{ .Domain }}
  issuerRef:
    name: {{ .IssuerName }}
    kind: ClusterIssuer