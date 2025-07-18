## 환경
```bash
$ ansible-playbook --version                                                                                              [19:07:59]
ansible-playbook [core 2.18.2]
  config file = None
  configured module search path = ['/Users/jeonghoonyu/.ansible/plugins/modules', '/usr/share/ansible/plugins/modules']
  ansible python module location = /opt/homebrew/Cellar/ansible/11.2.0/libexec/lib/python3.13/site-packages/ansible
  ansible collection location = /Users/jeonghoonyu/.ansible/collections:/usr/share/ansible/collections
  executable location = /opt/homebrew/bin/ansible-playbook
  python version = 3.13.2 (main, Feb  4 2025, 14:51:09) [Clang 15.0.0 (clang-1500.1.0.2.5)] (/opt/homebrew/Cellar/ansible/11.2.0/libexec/bin/python)
  jinja version = 3.1.5
  libyaml = True
```

## Ansible playbook 실행 방법
```bash
echo "password" > vault_password.txt 
ansible-playbook -i inventory/all.ini.vault playbook.yaml --vault-password-file vault_password.txt 
```