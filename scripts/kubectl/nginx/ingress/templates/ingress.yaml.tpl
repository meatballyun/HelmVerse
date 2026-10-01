apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: {{ .IngressName }}
  namespace: {{ .Namespace }}
  annotations:
    cert-manager.io/cluster-issuer: {{ .ClusterIssuer }}
    {{ .Annotations }}
spec:
  ingressClassName: {{ .IngressClass }}
  {{ if .EnableTLS }}tls:
    - hosts:
        - {{ .Host }}
      secretName: {{ .TLSSecret }}
  {{ end }}rules:
    - host: {{ .Host }}
      http:
        paths:
          - path: {{ .Path }}
            pathType: {{ .PathType }}
            backend:
              service:
                name: {{ .ServiceName }}
                port:
                  number: {{ .ServicePort }}