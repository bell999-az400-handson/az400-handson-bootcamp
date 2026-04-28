# AZ-400 Handson Web Application

Node.js + Express web application with Azure Key Vault and Application Insights integration.

## Features

- ✅ Express.js web server
- ✅ Azure Key Vault integration with Managed Identity
- ✅ Application Insights monitoring and custom metrics
- ✅ Docker support
- ✅ Health check endpoint
- ✅ Unit tests with Jest

## Endpoints

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/` | GET | Home page |
| `/health` | GET | Health check |
| `/secret` | GET | Key Vault test |
| `/info` | GET | Application info |
| `/metrics` | GET | Custom metrics |

## Environment Variables

| Variable | Description | Required |
|----------|-------------|----------|
| `PORT` | Server port (default: 3000) | No |
| `KEY_VAULT_URL` | Azure Key Vault URL | Yes |
| `APPLICATIONINSIGHTS_CONNECTION_STRING` | Application Insights connection string | Yes |
| `NODE_ENV` | Environment (development/production) | No |

## Local Development

```bash
# Install dependencies
npm install

# Run locally
npm start

# Run with auto-reload
npm run dev

# Run tests
npm test

# Run linter
npm run lint
```

## Docker

```bash
# Build image
docker build -t az400webapp:latest .

# Run container
docker run -p 3000:3000 \
  -e KEY_VAULT_URL=https://your-kv.vault.azure.net/ \
  -e APPLICATIONINSIGHTS_CONNECTION_STRING=your-connection-string \
  az400webapp:latest
```

## Deployment

See [Day 2](../../docs/handson/day2-azure-security.md) and [Day 3](../../docs/handson/day3-cicd-pipelines.md) for deployment instructions.
