# Etapa 1: Construir Flutter Web (versión fijada para builds reproducibles)
ARG FLUTTER_VERSION=3.35.2
FROM ghcr.io/cirruslabs/flutter:${FLUTTER_VERSION} AS build
WORKDIR /app

# Primero solo pubspec: la capa de dependencias se cachea entre builds.
COPY pubspec.yaml pubspec.lock ./
RUN flutter pub get

COPY . .

# URL del backend inyectada en el build. Railway puede sobreescribirla por
# servicio con el build arg API_BASE_URL.
ARG API_BASE_URL=https://lavaderoappnew-production.up.railway.app
RUN flutter build web --release --dart-define=API_BASE_URL=${API_BASE_URL}

# Etapa 2: Servir con Nginx sin privilegios (puerto 8080, usuario no root)
FROM nginxinc/nginx-unprivileged:1.27-alpine
COPY nginx.conf /etc/nginx/conf.d/default.conf
COPY --from=build /app/build/web /usr/share/nginx/html
EXPOSE 8080
HEALTHCHECK --interval=30s --timeout=3s --retries=3 \
  CMD wget -qO- http://127.0.0.1:8080/healthz >/dev/null || exit 1
