# Build stage
FROM --platform=$BUILDPLATFORM golang:1.23-alpine AS builder

ARG TARGETOS
ARG TARGETARCH
ARG VERSION=dev

WORKDIR /app

# Install build dependencies
RUN apk add --no-cache git

# Copy go mod files first for better caching
COPY go.mod go.sum ./
RUN go mod download

# Copy source code
COPY . .

# Build the binary
RUN CGO_ENABLED=0 GOOS=${TARGETOS} GOARCH=${TARGETARCH} go build \
    -ldflags="-s -w -X=sigs.k8s.io/karpenter/pkg/operator.Version=${VERSION}" \
    -o karpenter \
    ./cmd/controller

# Runtime stage - use distroless for security
FROM gcr.io/distroless/static:nonroot

WORKDIR /

COPY --from=builder /app/karpenter /karpenter

USER 65532:65532

ENTRYPOINT ["/karpenter"]