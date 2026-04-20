init:
	ansible-galaxy collection install -r ansible/collections/requirements.yml
	mkdir -p secrets/sops
	@if [ -z "$$AGE_SECRET_KEY" ] && [ ! -f secrets/sops/keys.txt ]; then \
		echo "No AGE_SECRET_KEY set and secrets/sops/keys.txt not found. Generating new age key..."; \
		age-keygen -o secrets/sops/keys.txt; \
	fi
	cp .blueprints/secrets/secrets.yaml.template secrets/secrets.yaml
	@if [ -z "$$(find ansible/inventory/host_vars -maxdepth 1 -name '*.yml' -o -name '*.yaml' 2>/dev/null)" ]; then \
		echo "No host_vars YAML files found. Copying templates..."; \
		for f in .blueprints/ansible/host_vars/*.yml.template; do \
			cp "$$f" "ansible/inventory/host_vars/$$(basename "$$f" .template)"; \
		done; \
	fi


decrypt:
	@echo "Decrypting secrets/sops/keys.txt..."
	@AGE_KEY_FILE=secrets/sops/keys.txt sops -d --input-type binary secrets/secrets.yaml > secrets/secrets.decrypted.yaml
	@echo "Decryption complete. Decrypted file: secrets/secrets.decrypted.yaml"

all:
	init stage-0 stage-1 stage-2 stage-3 stage-4 stage-5 stage-6 stage-7

stage-0:
	@AGE_KEY_FILE=secrets/sops/keys.txt && cd ansible && ansible-playbook -i inventory/hosts.yml stage_0.yml && cd ..
stage-1:
	@AGE_KEY_FILE=secrets/sops/keys.txt && cd ansible && ansible-playbook -i inventory/hosts.yml stage_1.yml && cd ..
stage-2:
	@AGE_KEY_FILE=secrets/sops/keys.txt && cd ansible && ansible-playbook -i inventory/hosts.yml stage_2.yml && cd ..
stage-3:
	@AGE_KEY_FILE=secrets/sops/keys.txt && cd terraform && terraform plan && terraform apply -auto-approve
stage-4:
	@AGE_KEY_FILE=secrets/sops/keys.txt && cd ansible && ansible-playbook -i inventory/hosts.yml stage_4.yml && cd ..
stage-5:
	@AGE_KEY_FILE=secrets/sops/keys.txt && cd ansible && ansible-playbook -i inventory/hosts.yml stage_5.yml && cd ..
stage-6:
	@AGE_KEY_FILE=secrets/sops/keys.txt && cd ansible && ansible-playbook -i inventory/hosts.yml stage_6.yml && cd ..
stage-7:
	@AGE_KEY_FILE=secrets/sops/keys.txt && cd ansible && ansible-playbook -i inventory/hosts.yml stage_7.yml && cd ..
