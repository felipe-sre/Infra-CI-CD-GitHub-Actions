# Repositório de Infraestrutura · Proxy Nginx Automatizado

Automação completa (Terraform + Ansible + Bitbucket Pipelines) para hospedar apps Docker
atrás de um Nginx reverse-proxy com SSL na DigitalOcean.

---

## Visão Geral

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

## Pré-requisitos

* Conta DigitalOcean + token (`DO_TOKEN`)  
* Terraform ≥ 1.4 • Ansible ≥ 9 • Python ≥ 3.9  
* Chave SSH adicionada na DigitalOcean  
* Variáveis seguras do Bitbucket:  
  `DO_TOKEN | DOCKER_USERNAME | DOCKER_PASSWORD | DOCKER_REPO`

---

## Provisionar ambiente *(ex.: staging)*

```bash
cd terraform
terraform init
terraform workspace new staging   # 1ª vez
terraform apply -var-file="../environments/staging.tfvars"
```

---

## Configurar host

```bash
ansible-playbook   -i ansible/inventory/tag_env_staging.yml   ansible/playbooks/configure_host.yml   -e "domain_name_var=d34.com.br certbot_email=contato@d34.com.br app_port=8081"
```

> Executa roles **common → docker → nginx**  
> Remove site default, gera SSL e deixa o proxy pronto.

---

## Deploy de aplicação

```bash
ansible-playbook   -i ansible/inventory/tag_env_staging.yml   ansible/playbooks/deploy_app.yml   -e "app_to_deploy=landing-page       full_image_path=registry.digitalocean.com/d34cr/landing-page:latest"
```

Pipeline `pipeline-deploy-app` faz exatamente esse comando em produção.

---

## Estrutura do Repositório <!-- árvore resumida -->
```
.
├── ansible/
│   ├── ansible.cfg
│   ├── inventory/
│   ├── playbooks/
│   │   ├── configure_host.yml
│   │   └── deploy_app.yml
│   └── roles/{common,docker,nginx,deploy_app}
├── terraform/
│   └── envs/{staging,production}
├── environments/*.tfvars
├── apps.yml
└── bitbucket-pipelines.yml
```

---

## FAQ Rápido

| Dúvida | Resposta |
|--------|----------|
| **Como adiciono um novo app?** | 1) Adicione no `apps.yml`.<br>2) Dê push na imagem para `${DOCKER_REPO}`.<br>3) Rode o pipeline manual `deploy-app`. |
| **Posso rodar múltiplos domínios no mesmo proxy?** | Sim. Execute `configure_host.yml` novamente com outras variáveis (`domain_name_var`, `app_port`). |
| **HTTPS não sobe!** | Verifique: domínio aponta p/ IP, porta 80 liberada, arquivo gerado em `/etc/letsencrypt/live/<domínio>/`. |

---

> _Esse README foca no **mínimo viável** para novos devs clonarem e operarem. Para detalhes extra (versionamento de Colections, testes, etc.) consulte `/docs` ou abra uma issue._