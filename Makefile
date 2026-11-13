CLUSTER ?= gitops-portfolio
CTX := kind-$(CLUSTER)

.PHONY: up cluster argocd root password down

up: cluster argocd root

cluster:
	kind create cluster --config kind/cluster.yaml

argocd:
	# server-side: the ApplicationSet CRD is too big for client-side apply's annotation
	kubectl --context $(CTX) apply -k bootstrap/argocd --server-side --force-conflicts
	kubectl --context $(CTX) -n argocd wait --for=condition=Available deploy --all --timeout=300s
	kubectl --context $(CTX) -n argocd rollout status sts/argocd-application-controller --timeout=300s

root:
	kubectl --context $(CTX) apply -f bootstrap/root-app.yaml

password:
	@kubectl --context $(CTX) -n argocd get secret argocd-initial-admin-secret \
		-o jsonpath='{.data.password}' | base64 -d; echo

down:
	kind delete cluster --name $(CLUSTER)
