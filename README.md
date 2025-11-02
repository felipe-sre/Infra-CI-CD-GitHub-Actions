# Guia Rápido - Pipeline CI/CD com GitHub Actions

Guia prático para usar o pipeline de infraestrutura automatizada (Terraform + Ansible + Docker) com GitHub Actions.

---

## Pré-requisitos

Antes de começar, certifique-se de ter:

- [ ] Conta na DigitalOcean
- [ ] Token de API da DigitalOcean (Read/Write)
- [ ] Chave SSH adicionada na DigitalOcean
- [ ] Repositório no GitHub configurado
- [ ] Docker Registry configurado (DigitalOcean Container Registry)

---

## Configuração Inicial (Uma Vez)

### 1. Configurar Secrets no GitHub

Vá em **Settings** → **Secrets and variables** → **Actions** → **New repository secret** e adicione:

| Secret | Descrição | Exemplo |
|--------|-----------|---------|
| `DO_API_TOKEN` | Token da DigitalOcean | `dop_v1_...` |
| `DOCKER_USERNAME` | Token da DigitalOcean | seu PAT na DO (pode ser o PAT_backend) |
| `DOCKER_PASSWORD` | Token da DigitalOcean | seu PAT na DO (pode ser o PAT_backend) |
| `DOCKER_REPO` | Caminho do registry | `registry.digitalocean.com/seu-container-registry` |
| `DO_SPACES_ACCESS_KEY` | Access key do Spaces | Para backend Terraform |
| `DO_SPACES_SECRET_KEY` | Secret key do Spaces | Para backend Terraform |
| `DO_SSH_KEY` | Chave SSH privada (base64) | Ver instruções abaixo |

**Para gerar `DO_SSH_KEY`:**
```bash
cat ~/.ssh/sua_chave_privada | base64 -w 0
```

### 2. Configurar Environment no GitHub

1. Vá em **Settings** → **Environments**
2. Crie um environment chamado `staging`
3. (Opcional) Configure proteções de deployment:
   - Reviewers obrigatórios
   - Wait timer
   - Branch restrictions

### 3. Configurar Apps

Edite `iacfull/apps.yaml`:

```yaml
apps:
  - name: landing-page
    image_name: "landing-page"
    route: "/"
    internal_port: 80
    host_port: 8080
  
  - name: minha-api
    image_name: "minha-api"
    route: "/api/"
    internal_port: 5000
    host_port: 8081
```

---

## Deploy Completo (Staging)

### Via GitHub Actions Interface

1. Vá em **Actions** no repositório
2. Selecione **CI/CD - Infraestrutura e Deploy**
3. Clique em **Run workflow**
4. Configure os parâmetros:
   - **Tipo de Pipeline**: `staging-deploy`
   - **Nome do Domínio**: `seu-dominio.com.br`
   - **E-mail para Certbot**: `seu-email@exemplo.com`
   - **Nome da Aplicação**: `landing-page`
   - **Tag da Imagem**: `latest`
5. Clique em **Run workflow**

**O que acontece:**
1. Build da imagem Docker e push para o registry
2. Terraform Plan - cria plano de infraestrutura
3. Terraform Apply - provisiona infraestrutura
4. Ansible configura servidor (Nginx, SSL, Docker)
5. Deploy da aplicação

**Total: ~7-10min**

### Via GitHub CLI (gh)

```bash
gh workflow run main.yml \
  -f pipeline_type=staging-deploy \
  -f domain_name=seu-dominio.com.br \
  -f certbot_email=seu-email@exemplo.com \
  -f app_name=landing-page \
  -f image_tag=latest
```

---

## Deploy de Nova Versão (Sem Recriar Infra)

Depois que a infraestrutura já existe, para atualizar apenas a aplicação:

### Via Actions Interface

1. **Actions** → **CI/CD - Infraestrutura e Deploy**
2. **Run workflow**
3. Configure:
   - **Tipo de Pipeline**: `deploy-app`
   - **Nome da Aplicação**: `landing-page`
   - **Tag da Imagem**: `v1.2.0` ou `latest`
4. **Run workflow**

### Via GitHub CLI

```bash
gh workflow run main.yml \
  -f pipeline_type=deploy-app \
  -f app_name=landing-page \
  -f image_tag=v1.2.0
```

**Tempo: ~1-2min**

---

## Tipos de Pipeline Disponíveis

| Pipeline | Descrição | Quando Usar |
|----------|-----------|-------------|
| `staging-deploy` | Deploy completo (infra + app) | Primeira vez ou recriação total |
| `full-deploy-app` | Build + Reconfig + Deploy | Atualizar app e reconfigurar Nginx |
| `build-and-push-image` | Só build e push da imagem | Testar build sem deploy |
| `terraform-plan-staging` | Só plan do Terraform | Verificar mudanças de infra |
| `terraform-apply-staging` | Só apply do Terraform | Aplicar mudanças de infra |
| `reconfigure-nginx` | Só reconfiguração do host | Atualizar configs Nginx/SSL |
| `deploy-app` | Só deploy da aplicação | Atualizar versão da app |

---

## 🧪 Validar Deploy

### 1. Verificar Workflow

No GitHub Actions, verifique que todos os jobs estão verdes 

### 2. Verificar DNS

```bash
dig seu-dominio.com.br
# Deve apontar para o IP do Droplet
```

### 3. Testar HTTPS

Abra no navegador:
```
https://seu-dominio.com.br
```

Deve mostrar:
- Cadeado (SSL válido)
- Conteúdo da sua aplicação

### 4. Verificar Logs

```bash
# Ver logs do workflow
gh run list --workflow=main.yml --limit 1
gh run view <RUN_ID> --log

# SSH no servidor
ssh -i ~/.ssh/sua_chave root@IP_DO_DROPLET
docker logs landing-page
docker ps
```

---

## Automação com Push

Para automatizar o deploy quando houver push em uma branch específica, edite `.github/workflows/main.yml`:

```yaml
on:
  push:
    branches:
      - main  # ou staging, develop, etc
    paths:
      - 'landing-page/**'  # apenas quando a app mudar
  
  workflow_dispatch:
    # ... mantém os inputs existentes
```

Depois adicione valores padrão no workflow para push automático:

```yaml
env:
  DOCKER_REPO: ${{ secrets.DOCKER_REPO }}
  # Para push automático, define valores default
  APP_NAME: ${{ github.event.inputs.app_name || 'landing-page' }}
  IMAGE_TAG: ${{ github.event.inputs.image_tag || github.sha }}
  FULL_IMAGE_PATH: ${{ secrets.DOCKER_REPO }}/${{ github.event.inputs.app_name || 'landing-page' }}:${{ github.event.inputs.image_tag || github.sha }}
```

---

## Adicionar Nova Aplicação

### 1. Adicione no `apps.yaml`

```yaml
apps:
  - name: nova-app
    image_name: "nova-app"
    route: "/nova/"
    internal_port: 3000
    host_port: 8082
```

### 2. Faça push da imagem

```bash
docker build -t registry.digitalocean.com/d35cr/nova-app:latest .
docker push registry.digitalocean.com/d35cr/nova-app:latest
```

### 3. Deploy

Execute workflow com:
- **Tipo de Pipeline**: `deploy-app`
- **Nome da Aplicação**: `nova-app`
- **Tag da Imagem**: `latest`

---

## Troubleshooting Comum

### Workflow falha em "Terraform Apply"

**Causa:** Problemas de permissão ou backend  
**Solução:** 
- Verifique se os secrets estão corretos
- Confirme que o Spaces bucket existe
- Tente executar `terraform-plan-staging` primeiro

### Workflow falha em "Deploy da App"

**Erro:** `Error connecting: Not supported URL scheme http+docker`  
**Solução:** Remova variáveis `environment: DOCKER_HOST` das tasks Docker no `deploy_app.yaml`

### SSL não funciona

**Verificar:**
1. DNS aponta para o IP correto? (`dig seu-dominio.com.br`)
2. Porta 80 está aberta? (necessária para validação Let's Encrypt)
3. Aguarde 5-10 minutos após primeira configuração
4. Verifique logs do job `reconfigure-nginx`

### Secrets não são reconhecidos

**Solução:**
1. Verifique se os secrets estão no repositório correto
2. Confirme que o nome dos secrets está exato (case-sensitive)
3. Verifique se o environment `staging` existe em Settings → Environments
4. Re-execute o workflow após adicionar secrets

---

## Melhorias Possíveis

### 1. Criar Workflows Separados

Em vez de um workflow monolítico, crie workflows específicos:

```
.github/workflows/
├── deploy-staging.yml      # Deploy completo staging
├── deploy-production.yml   # Deploy completo production
├── build-image.yml         # Só build de imagem
├── terraform.yml           # Só terraform
└── deploy-app-only.yml     # Só deploy de app
```

### 2. Usar Reusable Workflows

```yaml
# .github/workflows/deploy-reusable.yml
on:
  workflow_call:
    inputs:
      environment:
        required: true
        type: string
    secrets:
      DO_API_TOKEN:
        required: true
```

### 3. Adicionar Matrix Strategy

Para deploy em múltiplos ambientes:

```yaml
strategy:
  matrix:
    environment: [staging, production]
    app: [landing-page, api]
```

### 4. Adicionar Notificações

```yaml
- name: Notificar Slack
  if: always()
  uses: 8398a7/action-slack@v3
  with:
    status: ${{ job.status }}
    webhook_url: ${{ secrets.SLACK_WEBHOOK }}
```

---

## Próximos Passos

- [ ] Configure ambiente de **production** separado
- [ ] Adicione workflows específicos por ambiente
- [ ] Configure GitHub Environments com proteções
- [ ] Adicione testes automatizados antes do deploy
- [ ] Configure monitoramento (Uptime Robot, Datadog)
- [ ] Adicione validação de Terraform (`terraform fmt`, `tflint`)
- [ ] Configure cache para dependências Ansible/Python

---

## 🔗 Links Úteis

- [GitHub Actions Documentation](https://docs.github.com/actions)
- [GitHub Environments](https://docs.github.com/actions/deployment/targeting-different-environments/using-environments-for-deployment)
- [Reusing Workflows](https://docs.github.com/actions/using-workflows/reusing-workflows)
- [GitHub CLI](https://cli.github.com/)