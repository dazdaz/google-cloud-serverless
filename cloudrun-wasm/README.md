# GCP WASM Service Extensions Demos

Two demonstration projects showcasing WebAssembly (Wasm) with **GCP Service Extensions** for edge computing on Google Cloud Application Load Balancer.

[![Rust](https://img.shields.io/badge/Rust-1.75+-orange.svg)](https://www.rust-lang.org/)
[![TinyGo](https://img.shields.io/badge/TinyGo-0.30+-blue.svg)](https://tinygo.org/)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

---

## 🎯 What's Inside

| Demo | Description | Language | Location |
|------|-------------|----------|----------|
| [**01-Edge Security**](demos/01-edge-security/) | PII/PCI data scrubbing at the edge | Rust | Load Balancer (Service Extensions) |
| [**02-Smart Router**](demos/02-smart-router/) | A/B testing & canary routing | TinyGo | Load Balancer (Service Extensions) |

---

## 🏗️ Architecture Overview

Both demos use **GCP Service Extensions** to run Wasm plugins inside the Load Balancer, with **Cloud Run** as the backend service.

```
┌──────────────────────────────────────────────────────────────────────────┐
│                       GCP Application Load Balancer                      │
│  ┌────────────────────────────────────────────────────────────────────┐  │
│  │                  Service Extensions (Wasm Sandbox)                 │  │
│  │                                                                    │  │
│  │   REQUEST PATH:   Demo 2 - Smart Router                           │  │
│  │                   • Inspect headers/cookies          │  │
│  │                   • Route to v1 or v2 backend        │  │
│  │                                                                    │  │
│  │   RESPONSE PATH:  Demo 1 - PII Scrubbing                          │  │
│  │                   • Scan response body               │  │
│  │                   • Redact credit cards, SSN, emails │  │
│  └────────────────────────────────────────────────────────────────────┘  │
│                                     │                                    │
└─────────────────────────────────────┼────────────────────────────────────┘
                                      │
                                      ▼
┌──────────────────────────────────────────────────────────────────────────┐
│                            Cloud Run Backend                             │
│                                                                          │
│   • Receives traffic from Load Balancer (after Wasm processing)         │
│   • Returns JSON responses (may contain PII for Demo 1 testing)         │
│   • Hosts v1 and v2 versions for A/B testing (Demo 2)                   │
│                                                                          │
└──────────────────────────────────────────────────────────────────────────┘
```

### How Cloud Run Fits In

| Demo | Cloud Run Role |
|------|----------------|
| **Demo 1: PII Scrubbing** | Returns user data with PII (SSN, credit cards). Wasm scrubs it on the way out. |
| **Demo 2: Smart Router** | Hosts multiple versions (v1, v2). Wasm routes traffic based on user attributes. |

---

## 🚀 Quick Start

### Prerequisites

```bash
# Verify required tools
./scripts/setup-dev.sh --verify

# Or install manually on macOS:
brew install rustup docker tinygo

# Setup Rust for Wasm
rustup-init
rustup target add wasm32-unknown-unknown
```

### Build & Run All Demos

```bash
# Clone the repository
git clone https://github.com/yourorg/cloudrun-wasm.git
cd cloudrun-wasm

# Setup development environment
./scripts/setup-dev.sh

# Build all demos
make build

# Start local environment (Envoy + Mock Backend)
make docker-up

# Test Demo 1: PII Scrubbing
curl http://localhost:10000/api/user
# Output: SSN and credit cards are redacted!

# Test Demo 2: Smart Routing
curl -H "Cookie: beta-tester=true" \
     -H "User-Agent: iPhone" \
     -H "X-Geo-Country: DE" \
     http://localhost:10001/api/version
# Output: Routed to v2-beta!

# Stop environment
make docker-down
```

---

## 📖 Documentation

| Document | Description |
|----------|-------------|
| [PROJECT_OVERVIEW.md](PROJECT_OVERVIEW.md) | Architecture diagrams & design decisions |
| [CODE_PRINCIPLES.md](CODE_PRINCIPLES.md) | Coding standards & style guide |
| [CONTRIBUTING.md](CONTRIBUTING.md) | Setup guides & how-to instructions |
| [DATA_STRUCTURES.md](DATA_STRUCTURES.md) | Type definitions & test fixtures |
| [TODO.md](TODO.md) | Implementation checklist |

---

## 📁 Project Structure

```
cloudrun-wasm/
├── demos/
│   ├── 01-edge-security/           # Demo 1: PII Scrubbing (Rust)
│   │   ├── src/lib.rs              # Main plugin logic
│   │   ├── src/patterns.rs         # PII regex patterns
│   │   ├── Cargo.toml              # Rust dependencies
│   │   ├── Makefile                # Build automation
│   │   └── README.md               # Demo documentation
│   │
│   └── 02-smart-router/            # Demo 2: A/B Testing (TinyGo)
│       ├── main.go                 # Plugin entry point
│       ├── router/                 # Routing logic
│       │   ├── types.go            # Rule definitions
│       │   ├── router.go           # Decision engine
│       │   └── cookie.go           # Cookie parser
│       ├── go.mod                  # Go module
│       ├── Makefile                # Build automation
│       └── README.md               # Demo documentation
│
├── infrastructure/
│   ├── envoy/                      # Envoy configurations
│   │   ├── envoy.yaml              # Base config
│   │   ├── envoy-demo1.yaml        # Demo 1 (response filter)
│   │   └── envoy-demo2.yaml        # Demo 2 (request filter)
│   │
│   ├── docker/                     # Docker files
│   │   └── Dockerfile.envoy        # Envoy with Wasm
│   │
│   ├── backend/                    # Cloud Run backend
│   │   ├── app.py                  # Flask API server
│   │   ├── Dockerfile              # Python container
│   │   ├── service.yaml            # Cloud Run config
│   │   └── README.md               # API docs
│   │
│   └── gcp/                        # GCP deployment
│       ├── load-balancer.tf        # Terraform config
│       ├── wasm-plugin-demo1.yaml  # Demo 1 WasmPlugin
│       └── wasm-plugin-demo2.yaml  # Demo 2 WasmPlugin
│
├── scripts/
│   ├── setup-dev.sh                # Dev environment setup
│   ├── build-all.sh                # Build all Wasm modules
│   ├── test-all.sh                 # Run all tests
│   └── deploy-cloudrun.sh          # Deploy to GCP
│
├── .vscode/                        # VS Code configuration
│   ├── settings.json               # Workspace settings
│   └── extensions.json             # Recommended extensions
│
├── Makefile                        # Root build automation
├── .gitignore                      # Git ignore rules
└── *.md                            # Documentation files
```

---

## 🔧 Why Wasm at the Edge?

| Benefit | Description |
|---------|-------------|
| **🔒 Secure** | Sandboxed execution - plugins can't crash the host |
| **⚡ Fast** | Microsecond latency, no network hop to external service |
| **🌍 Portable** | Write once, run on Envoy (local) or GCP LB (production) |
| **🔧 Flexible** | Modify requests/responses without backend code changes |

---

## 📊 Use Cases

### Demo 1: Edge Security (PII Scrubbing)
> "Scrub sensitive data before it leaves your network"

**Problem**: Backend returns user data that might contain PII. You need to ensure it never reaches the client.

**Solution**: Wasm plugin scans response body and redacts:
- Credit card numbers → `XXXX-XXXX-XXXX-1234`
- SSNs → `XXX-XX-XXXX`
- Email addresses → `[EMAIL REDACTED]`

### Demo 2: Smart Router (A/B Testing)
> "Route traffic at the edge, not in your app"

**Problem**: You want to send specific users (iPhone + Germany + beta flag) to a new backend version.

**Solution**: Wasm plugin inspects request headers and routes to:
- `v1` backend for standard users
- `v2` backend for beta testers matching criteria

---

## 🧪 Testing

```bash
# Run all tests
make test

# Individual demos
cd demos/01-edge-security && cargo test
cd demos/02-smart-router && go test ./...

# Integration tests with Envoy
make integration-test

# Run all tests via script
./scripts/test-all.sh
```

---

## 🔧 Development

### Make Commands

```bash
make build            # Build all Wasm modules
make test             # Run all tests
make clean            # Clean build artifacts
make lint             # Run linters
make docker-up        # Start local environment
make docker-down      # Stop local environment
make docker-logs      # View container logs
make deploy           # Deploy to GCP (requires auth)
```

### Demo-specific Commands

```bash
# Demo 1: Edge Security
cd demos/01-edge-security
make build            # Build Wasm
make test             # Run tests
make deploy-local     # Copy to Envoy

# Demo 2: Smart Router
cd demos/02-smart-router
make build            # Build Wasm
make test             # Run tests
make deploy-local     # Copy to Envoy
```

---

## 🚀 GCP Deployment

### Prerequisites
- GCP Project with billing enabled
- `gcloud` CLI authenticated
- Artifact Registry enabled

### Deploy

```bash
# Deploy backend to Cloud Run
./scripts/deploy-cloudrun.sh

# Apply Terraform for Load Balancer
cd infrastructure/gcp
terraform init
terraform apply

# Deploy Wasm plugins
gcloud service-extensions wasm-plugins create demo1-pii \
  --config-file=wasm-plugin-demo1.yaml

gcloud service-extensions wasm-plugins create demo2-router \
  --config-file=wasm-plugin-demo2.yaml
```

---

## 📚 Learn More

- [Proxy-Wasm Specification](https://github.com/proxy-wasm/spec)
- [GCP Service Extensions](https://cloud.google.com/service-extensions/docs)
- [Envoy Wasm Filters](https://www.envoyproxy.io/docs/envoy/latest/configuration/http/http_filters/wasm_filter)
- [proxy-wasm-rust-sdk](https://github.com/proxy-wasm/proxy-wasm-rust-sdk)
- [proxy-wasm-go-sdk](https://github.com/tetratelabs/proxy-wasm-go-sdk)

---

## 📄 License

MIT License - See [LICENSE](LICENSE) for details.

---

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'feat: add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

See [CONTRIBUTING.md](CONTRIBUTING.md) for detailed guidelines.