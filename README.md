# 🚀 Guia Rápido - Pipeline CI/CD Automatizado

Guia prático para usar o pipeline de infraestrutura automatizada (Terraform + Ansible + Docker).

---

## 📋 Pré-requisitos

Antes de começar, certifique-se de ter:

- [ ] Conta na DigitalOcean
- [ ] Token de API da DigitalOcean (Read/Write)
- [ ] Chave SSH adicionada na DigitalOcean
- [ ] Conta no Bitbucket com o repositório configurado
- [ ] Docker Registry configurado (DigitalOcean Container Registry)

---

## ⚙️ Configuração Inicial (Uma Vez)

### 1. Configurar Variáveis no Bitbucket

Vá em **Repository Settings** → **Pipelines** → **Repository variables** e adicione:

| Variável | Descrição | Exemplo |
|----------|-----------|---------|
| `DO_API_TOKEN` | Token da DigitalOcean | `dop_v1_...` |
| `DOCKER_USERNAME` | Token da DigitalOcean | seu PAT na 'DO' (pode ser o 'PAT_backend')|
| `DOCKER_PASSWORD` | Token da DigitalOcean | seu PAT na 'DO' (pode ser o 'PAT_backend')|
| `DOCKER_REPO` | Caminho do registry | `registry.digitalocean.com/d35cr` |
| `DO_SPACES_ACCESS_KEY` | Access key do Spaces | Para backend Terraform |
| `DO_SPACES_SECRET_KEY` | Secret key do Spaces | Para backend Terraform |
| `DO_SSH_KEY` | Chave SSH privada (base64) | Ver instruções abaixo |

**Para gerar `DO_SSH_KEY`:**
```bash
cat ~/.ssh/sua_chave_privada | base64 -w 0
```

### 2. Configurar Apps

Edite `cleaners-infra/cleaner-infra-nginx-proxies/apps.yaml`:

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

## 🏗️ Deploy Completo (Staging)

### Opção 1: Pipeline Manual (Recomendado)

1. Vá em **Pipelines** no Bitbucket
2. Clique em **Run pipeline**
3. Selecione **custom: staging-deploy**
4. Configure as variáveis (ou use os defaults):
   - `DOMAIN_NAME`: `seu-dominio.com.br`
   - `CERTBOT_EMAIL`: `seu-email@exemplo.com`
   - `APP_NAME`: `landing-page`
   - `IMAGE_TAG`: `latest`
5. Clique em **Run**

**O que acontece:**
1. ✅ Build da imagem Docker e push para o registry (9s)
2. ✅ Terraform Plan - cria plano de infraestrutura (8s)
3. ⚠️ Terraform Apply - requer aprovação manual (28s)
4. ✅ Ansible configura servidor (Nginx, SSL, Docker) (4m 57s)
5. ✅ Deploy da aplicação (1m 20s)

**Total: ~7min**

### Opção 2: Por Steps Individuais

Se algo falhar, você pode rodar steps individuais:

```bash
# No Bitbucket Pipelines, escolha:
custom: build-and-push-image       # Só build da imagem
custom: terraform-plan-staging     # Só plan
custom: terraform-apply-staging    # Só apply
custom: reconfigure-nginx          # Só configuração
custom: deploy-app                 # Só deploy
```

---

## 📦 Deploy de Nova Versão (Sem Recriar Infra)

Depois que a infraestrutura já existe, para atualizar apenas a aplicação:

### Via Pipeline

1. **Pipelines** → **Run pipeline**
2. Selecione **custom: deploy-app**
3. Configure:
   - `APP_NAME`: nome da app em `apps.yaml`
   - `IMAGE_TAG`: versão da imagem (ex: `v1.2.0`, `latest`)
4. **Run**

**Tempo: ~1m 20s**

---

## 🧪 Validar Deploy

### 1. Verificar Pipeline

No Bitbucket, verifique que todos os steps estão verdes ✅

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
- 🔒 Cadeado (SSL válido)
- Conteúdo da sua aplicação

### 4. Verificar Logs (Opcional)

SSH no servidor:
```bash
ssh -i ~/.ssh/sua_chave root@IP_DO_DROPLET

# Ver logs do container
docker logs landing-page

# Ver status
docker ps
```

---

## 🧹 Adicionar Nova Aplicação

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

Pipeline **custom: deploy-app** com:
- `APP_NAME`: `nova-app`
- `IMAGE_TAG`: `latest`

---

## 🔧 Troubleshooting Comum

### Pipeline falha no "Terraform Apply"

**Causa:** Step requer aprovação manual  
**Solução:** Clique em "Run" no step manualmente no Bitbucket

### Pipeline falha no "Deploy da App"

**Erro comum:** `Error connecting: Not supported URL scheme http+docker`  
**Solução:** Remova `environment: DOCKER_HOST` das tasks Docker no `deploy_app.yaml`

### SSL não funciona

**Verificar:**
1. DNS aponta para o IP correto? (`dig seu-dominio.com.br`)
2. Porta 80 está aberta? (necessária para validação Let's Encrypt)
3. Aguarde 5-10 minutos após primeira configuração

### Container não sobe

**Debug:**
```bash
# SSH no servidor
ssh root@IP_DO_DROPLET

# Ver logs do container
docker logs nome-da-app

# Ver status de todos containers
docker ps -a

# Tentar rodar manualmente
docker run -p 8080:80 registry.digitalocean.com/d34cr/landing-page:latest
```

---

## 📊 Estrutura de Custos (Estimativa)

| Recurso | Tamanho | Custo/mês |
|---------|---------|-----------|
| Droplet | 1 vCPU, 1GB RAM | $6 |
| Spaces (backend Terraform) | 250GB inclusos | $5 |
| Container Registry | 500MB inclusos | Grátis |
| **Total** | | **~$11/mês** |

---

## 🗑️ Destruir Ambiente (Opcional)

Para parar os custos e remover tudo:

```bash
# Local
cd terraform/
terraform workspace select staging
terraform destroy
```

**Atenção:** Isso remove:
- Droplet
- DNS Records
- Firewall
- Tudo gerenciado pelo Terraform

---

## 📚 Próximos Passos

- [ ] Configure ambiente de **production** (copie e ajuste `staging.tfvars`)
- [ ] Adicione monitoramento (Uptime Robot, Datadog, etc)
- [ ] Configure backups automáticos no Droplet
- [ ] Adicione mais aplicações no `apps.yaml`
- [ ] Configure pipeline automático na branch `main`

---
