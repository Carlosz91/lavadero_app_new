# Etapa 1: Construir Flutter Web
FROM ghcr.io/cirruslabs/flutter:stable AS build
WORKDIR /app
COPY . .

# URL del backend inyectada en el build. Railway puede sobreescribirla por
# servicio con el build arg API_BASE_URL.
ARG API_BASE_URL=https://lavaderoappnew-production.up.railway.app
RUN flutter build web --dart-define=API_BASE_URL=${API_BASE_URL}

# Etapa 2: Servir con Nginx
FROM nginx:1.27-alpine
COPY --from=build /app/build/web /usr/share/nginx/html
EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
