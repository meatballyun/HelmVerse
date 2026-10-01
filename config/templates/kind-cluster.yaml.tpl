kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
networking:
  podSubnet: "%%POD_SUBNET%%"
  serviceSubnet: "%%SERVICE_SUBNET%%"
nodes:
%%NODES%%