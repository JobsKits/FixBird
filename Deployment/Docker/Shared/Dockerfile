ARG GO_VERSION=1.26.8

FROM --platform=$BUILDPLATFORM golang:${GO_VERSION}-alpine AS builder
WORKDIR /src
COPY Server/go.mod Server/go.sum ./
RUN go mod download
COPY Server/ ./
ARG TARGETOS=linux
ARG TARGETARCH
RUN CGO_ENABLED=0 GOOS=$TARGETOS GOARCH=$TARGETARCH go build -trimpath -ldflags="-s -w" -o /out/api ./cmd/api
RUN CGO_ENABLED=0 GOOS=$TARGETOS GOARCH=$TARGETARCH go build -trimpath -ldflags="-s -w" -o /out/migrate ./cmd/migrate

FROM alpine:3.22
ARG APP_BUILD_VERSION=demo-local
LABEL org.opencontainers.image.version=$APP_BUILD_VERSION
RUN apk add --no-cache ca-certificates tzdata
WORKDIR /app
COPY --from=builder /out/api /app/api
COPY --from=builder /out/migrate /app/migrate
COPY Server/migrations /app/migrations
COPY Server/seeds /app/seeds
COPY WebAdmin /app/WebAdmin
COPY Web /app/Web
COPY Deployment/Docker/Shared/entrypoint.sh /app/entrypoint.sh
RUN chmod 0555 /app/entrypoint.sh /app/api /app/migrate
ENV APP_ADDR=:8080
ENV ADMIN_WEB_DIR=/app/WebAdmin
ENV WEB_DIR=/app/Web
ENV DEMO_MODE=true
ENV ALLOW_DEMO_NETWORK=true
ENV APP_BUILD_VERSION=$APP_BUILD_VERSION
EXPOSE 8080
ENTRYPOINT ["/app/entrypoint.sh"]
