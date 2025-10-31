# Repositório de Infraestrutura · Proxy Nginx Automatizado

Automação completa (Terraform + Ansible + Bitbucket Pipelines) para hospedar apps Docker
atrás de um Nginx reverse-proxy com SSL na DigitalOcean.

---

## 1. Visão Geral

### • IaC — Terraform  
Provisiona Droplets, Firewalls, DNS, VPC e Storage opcionais.

### • Configuração — Ansible  
Roles:
| Role | Função |
|------|--------|
| `common` | Pacotes básicos e hardening mínimo |
| `docker` | Instala Docker Engine + SDK Python |
| `nginx`  | Proxy reverso, SSL Let's Encrypt, redireciono HTTP→HTTPS |
| `deploy_app` | Faz pull da imagem Docker e sobe/atualiza o container |

### • CI/CD — Bitbucket Pipelines  
*1 pipeline* → **2 estágios**  
1. `terraform-plan/apply` (infra)  
2. `pipeline-deploy-app` (deploy de imagem a cada push na *main*)

### • Fonte-Única da Verdade  
`apps.yml` descreve **nome, portas e imagem** de cada aplicação.

---

## 2. Pré-requisitos

* Conta DigitalOcean + token (`DO_TOKEN`)  
* Terraform ≥ 1.4 • Ansible ≥ 9 • Python ≥ 3.9  
* Chave SSH pública adicionada na DigitalOcean  
* Variáveis seguras do Bitbucket:  
  `DO_API_TOKEN | DOCKER_USERNAME | DOCKER_PASSWORD | DOCKER_REPO`
* Defina `usuário`, `email`, `domínio` e `subdomínio` em: ~/ansible/playbooks/playbook.yml.
* Adicione o **caminho para sua chave pública** em (line 33): /ansible/roles/common/tasks/main.yaml

---

## 3. Como Replicar e Operar o Ambiente (Ex: Staging)

Siga estes passos para configurar o ambiente pela primeira vez ou replicá-lo.

### 3.1. Configuração Inicial (Primeira Vez)

1.  **Clonar o Repositório:**
    ```bash
    git clone git@bitbucket.org:d34tecnologia/cleaners-infra.git
    cd cleaners-infra
    ```
2.  **Configurar Tokens de Acesso:** Exporte o Token da DigitalOcean na sua sessão de terminal. Ele será usado pelo Terraform e pelo Ansible. **Para gerar/acessar seu token, acesse: seu painel Digital Ocean > API > Tokens. (guarde-o num local, pois ele é de visualização única)**
    ```bash
    export DIGITALOCEAN_TOKEN="SEU_TOKEN_DO_READ_WRITE"
    export DO_TOKEN=DIGITALOCEAN_TOKEN # Para o inventário dinâmico Ansible
    ```        
3.  **Configurar Chave SSH Ansible:**
    * Edite o arquivo `ansible/ansible.cfg`.
    * Garanta que a linha `private_key_file` aponte para o caminho **exato** da sua **chave privada** local:
        ```ini
        # ansible/ansible.cfg
        private_key_file = ~/.ssh/authorized_keys # Substitua pelo nome da sua chave privada
        ```
4.  **Inicializar Terraform e Backend:**
    * Navegue até o diretório `terraform/`.

---

### 3.2 Provisionar Infraestrutura *(ex.: staging)*

```bash
cd terraform
terraform workspace new staging
terraform plan
terraform apply
```
*Aguarde a criação do Droplet, Banco de Dados, DNS, etc.*
*Confirme que o Firewall está protegendo a droplet. Caso não esteja, execute:*
`terraform taint module.firewall.digitalocean_firewall.web_fw`
*Ele irá destruir o Firewall antigo e criar um novo Firewall.*

---

## 4. Configurar host

Após o `terraform apply` ser concluído, o Ansible configurará o Droplet recém-criado.

1.  Navegue até o diretório `ansible/`.
2.  **Verifique o Token:** Certifique-se de que `export DO_TOKEN` foi executado nesta sessão.
2.1 `export` DO_TOKEN=SEU_PAT_NA_DO.

```bash
ansible-playbook -i digitalocean.yaml playbooks/playbook.yml --limit app-server
```

* Use `--limit` associado ao **name** da droplet específica que o ansible irá atacar.
* Você também poderá ver o **name** da droplet em **playbooks/playbook.yml** `hosts = name`
* **O que acontece:** O Ansible usa o inventário dinâmico (`digitalocean.yaml`) para encontrar o IP do Droplet com a tag correta (definida no Terraform - ex.: env:staging). Em seguida, executa as roles `common` → `docker` → `nginx`. Remove o site default do Nginx, gera os certificados SSL via Certbot e deixa o proxy reverso pronto para a porta `app_port`.
* A execução deve terminar com `failed=0`.

---

### 4.1. Validação do Ambiente

1 **Acesso SSH:** Conecte-se ao Droplet (pode abrir um console droplet pela DO) como usuário `darlan` usando sua chave SSH:
  
    ```bash
    # Obtenha o IP via Terraform (se necessário): terraform output -raw app_server_ip
    ssh -i ~/.ssh/SUA_CHAVE_PRIVADA darlan@IP_DO_DROPLET
    ```

2.  **Verificações no Droplet:**
    * `sudo nginx -t` (Deve retornar OK).
    * `sudo systemctl status nginx` (Deve estar `active (running)`).
    * `sudo ufw status` (Deve estar `active` com portas 22, 80, 443 ALLOW).
    * `sudo ls -l /etc/letsencrypt/live/` (Deve mostrar a pasta do certificado para `domain_name_var`).

3.  **Verificação Externa:** Abra um navegador e acesse um dos subdomínios configurados (ex: `https://geo.damasio34.com.br`).
    * Você deve ver um **cadeado (conexão segura HTTPS)** e um erro **`502 Bad Gateway`**.

---

## 5. Deploy de aplicação

```bash
ansible-playbook   -i ansible/inventory/tag_env_staging.yml   ansible/playbooks/deploy_app.yml   -e "app_to_deploy=landing-page       full_image_path=registry.digitalocean.com/d34cr/landing-page:latest"
```

Pipeline `pipeline-deploy-app` faz exatamente esse comando em produção.

---

### 5.1. Destruição do Ambiente (Opcional)

Para remover todos os recursos gerenciados pelo Terraform e parar os custos:

1.  Navegue até o diretório `terraform/`.
2.  Garanta que `export DIGITALOCEAN_TOKEN` esteja ativo.
3.  Execute: `terraform destroy`.

---

## Estrutura do Repositório <!-- árvore resumida -->
```
.
├── ansible/
│   ├── group_vars/
│   │   ├── tag_env_production.yml
│   │   └── tag_env_staging.yml
│   ├── playbooks/
│   │   ├── configure_host.yaml
│   │   ├── deploy_app.yaml
│   │   └── playbook.yml
│   ├── roles/
│   │   ├── common/
│   │   ├── docker/
│   │   └── nginx/
│   ├── ansible.cfg
│   ├── digitalocean.yaml
│   └── requirements.yml
├── environments/
│   ├── production.tfvars
│   └── staging.tfvars
├── terraform/
│   ├── .terraform/
│   ├── modules/
│   │   ├── droplet/
│   │   └── firewall/
│   ├── backend.tf
│   ├── main.tf
│   ├── outputs.tf
│   ├── providers.tf
│   ├── variables.tf
│   └── terraform.tfstate* (Arquivos de estado e backup)
├── .gitignore
├── apps.yml
├── bitbucket-pipelines.yml
├── docker-compose.yml
└── README.md
```

---

## FAQ Rápido

| Dúvida | Resposta |
|--------|----------|
| **Como adiciono um novo app?** | 1) Adicione no `apps.yml`.<br>2) Dê push na imagem para `${DOCKER_REPO}`.<br>3) Rode o pipeline manual `deploy-app`. |
| **Posso rodar múltiplos domínios no mesmo proxy?** | Sim. Execute `configure_host.yml` novamente com outras variáveis (`domain_name_var`, `app_port`). |
| **HTTPS não sobe!** | Verifique: domínio aponta p/ IP, porta 80 liberada, arquivo gerado em `/etc/letsencrypt/live/<domínio>/`. |

---
