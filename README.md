## Ansible playbook 실행 방법
```bash
echo "password" > vault_password.txt 
ansible-playbook -i inventory/all.ini.vault playbook.yaml --vault-password-file vault_password.txt 
```