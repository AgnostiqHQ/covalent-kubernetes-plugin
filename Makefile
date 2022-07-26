.PHONY: all deploy clean

all: 
	@echo "To deploy infrastructure, use the command 'make deploy'."
	@echo "To tear down infrastructure, use 'make clean'."

deploy:
	(cd infra && . deploy-eks.sh)

clean:
	(cd infra && terraform destroy -auto-approve)
	rm -f infra/cluster_autoscaler.yml
