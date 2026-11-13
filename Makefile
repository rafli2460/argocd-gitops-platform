CLUSTER ?= gitops-portfolio
CTX := kind-$(CLUSTER)

.PHONY: up cluster argocd grafana-secret root password grafana-password down

up: cluster argocd grafana-secret root

cluster:
	kind create cluster --config kind/cluster.yaml

argocd:
	# server-side: the ApplicationSet CRD is too big for client-side apply's annotation
	kubectl --context $(CTX) apply -k bootstrap/argocd --server-side --force-conflicts
	kubectl --context $(CTX) -n argocd wait --for=condition=Available deploy --all --timeout=300s
	kubectl --context $(CTX) -n argocd rollout status sts/argocd-application-controller --timeout=300s

# Grafana admin login lives outside Git (public repo). Created once; reruns keep the existing password.
grafana-secret:
	kubectl --context $(CTX) create namespace monitoring --dry-run=client -o yaml | kubectl --context $(CTX) apply -f -
	kubectl --context $(CTX) -n monitoring get secret grafana-admin >/dev/null 2>&1 || \
		kubectl --context $(CTX) -n monitoring create secret generic grafana-admin \
			--from-literal=admin-user=admin \
			--from-literal=admin-password="$$(head -c 24 /dev/urandom | base64 | tr -d '/+=')"

root:
	kubectl --context $(CTX) apply -f bootstrap/root-app.yaml

password:
	@kubectl --context $(CTX) -n argocd get secret argocd-initial-admin-secret \
		-o jsonpath='{.data.password}' | base64 -d; echo

grafana-password:
	@kubectl --context $(CTX) -n monitoring get secret grafana-admin \
		-o jsonpath='{.data.admin-password}' | base64 -d; echo

down:
	kind delete cluster --name $(CLUSTER)
