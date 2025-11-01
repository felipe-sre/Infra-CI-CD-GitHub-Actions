# Usar nginx alpine para ser leve
FROM nginx:alpine

# Copiar o arquivo HTML para o diretório padrão do nginx
COPY index.html /usr/share/nginx/html/

# Copiar configuração customizada do nginx
COPY nginx.conf /etc/nginx/conf.d/default.conf

# Expor a porta 80
EXPOSE 80

# O nginx já inicia automaticamente com a imagem base