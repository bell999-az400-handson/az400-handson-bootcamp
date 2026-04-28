const express = require('express');
const appInsights = require('applicationinsights');
const { DefaultAzureCredential } = require('@azure/identity');
const { SecretClient } = require('@azure/keyvault-secrets');

// Application Insights初期化
const connectionString = process.env.APPLICATIONINSIGHTS_CONNECTION_STRING;
if (connectionString) {
  appInsights.setup(connectionString)
    .setAutoCollectRequests(true)
    .setAutoCollectPerformance(true)
    .setAutoCollectExceptions(true)
    .setAutoCollectDependencies(true)
    .setAutoCollectConsole(true)
    .setUseDiskRetryCaching(true);
  appInsights.start();
  console.log('✅ Application Insights initialized');
} else {
  console.log('⚠️  Application Insights not configured');
}

const app = express();
const port = process.env.PORT || 3000;

// Middleware
app.use(express.json());
app.use((req, res, next) => {
  console.log(`${new Date().toISOString()} - ${req.method} ${req.path}`);
  next();
});

// Key Vaultクライアント初期化
let secretClient;
const keyVaultUrl = process.env.KEY_VAULT_URL;
if (keyVaultUrl) {
  const credential = new DefaultAzureCredential();
  secretClient = new SecretClient(keyVaultUrl, credential);
  console.log(`✅ Key Vault client initialized: ${keyVaultUrl}`);
} else {
  console.log('⚠️  Key Vault URL not configured');
}

// ルート
app.get('/', (req, res) => {
  // カスタムメトリクス送信
  if (appInsights.defaultClient) {
    appInsights.defaultClient.trackEvent({ name: 'HomePage_Accessed' });
    appInsights.defaultClient.trackMetric({ name: 'HomePage_ResponseTime', value: Date.now() });
  }
  
  res.send(`
    <html>
      <head><title>AZ-400 Handson</title></head>
      <body>
        <h1>🚀 AZ-400 Handson Web App</h1>
        <p>Status: <strong>Running</strong></p>
        <p>Version: 1.0.0</p>
        <hr>
        <h2>Available Endpoints:</h2>
        <ul>
          <li><a href="/health">GET /health</a> - Health check</li>
          <li><a href="/secret">GET /secret</a> - Key Vault test</li>
          <li><a href="/info">GET /info</a> - Application info</li>
        </ul>
      </body>
    </html>
  `);
});

// ヘルスチェック
app.get('/health', (req, res) => {
  const health = {
    status: 'healthy',
    timestamp: new Date().toISOString(),
    uptime: process.uptime(),
    environment: process.env.NODE_ENV || 'development',
    keyVault: keyVaultUrl ? 'configured' : 'not configured',
    appInsights: connectionString ? 'configured' : 'not configured'
  };
  
  res.json(health);
});

// Key Vaultテスト
app.get('/secret', async (req, res) => {
  if (!secretClient) {
    return res.status(500).json({ 
      error: 'Key Vault not configured',
      message: 'KEY_VAULT_URL environment variable not set'
    });
  }

  try {
    const secretName = 'DatabaseConnectionString';
    const secret = await secretClient.getSecret(secretName);
    
    // セキュリティのため、実際の値は返さない
    res.json({
      secretName: secretName,
      retrieved: true,
      message: '✅ Secret retrieved from Key Vault successfully!',
      vaultUrl: keyVaultUrl,
      // 実際の値は返さない（セキュリティ）
      // value: secret.value  // ❌ 本番では絶対にやらない
    });
    
    // カスタムイベント送信
    if (appInsights.defaultClient) {
      appInsights.defaultClient.trackEvent({ name: 'Secret_Retrieved', properties: { secretName } });
    }
  } catch (error) {
    console.error('❌ Error retrieving secret:', error);
    
    // エラー送信
    if (appInsights.defaultClient) {
      appInsights.defaultClient.trackException({ exception: error });
    }
    
    res.status(500).json({ 
      error: error.message,
      secretName: 'DatabaseConnectionString',
      retrieved: false
    });
  }
});

// アプリケーション情報
app.get('/info', (req, res) => {
  const info = {
    name: 'AZ-400 Handson Web App',
    version: '1.0.0',
    description: 'AZ-400試験対策のハンズオン用Webアプリケーション',
    environment: process.env.NODE_ENV || 'development',
    nodeVersion: process.version,
    platform: process.platform,
    uptime: process.uptime(),
    memory: process.memoryUsage(),
    configuration: {
      port: port,
      keyVault: keyVaultUrl || 'not configured',
      appInsights: connectionString ? 'enabled' : 'disabled'
    }
  };
  
  res.json(info);
});

// カスタムメトリクスサンプル
app.get('/metrics', (req, res) => {
  if (appInsights.defaultClient) {
    // カスタムメトリクス送信
    appInsights.defaultClient.trackMetric({ name: 'CustomMetric', value: Math.random() * 100 });
    appInsights.defaultClient.trackEvent({ name: 'MetricsEndpoint_Accessed' });
    
    res.json({ message: 'Metrics sent to Application Insights' });
  } else {
    res.status(500).json({ error: 'Application Insights not configured' });
  }
});

// エラーハンドリング
app.use((err, req, res, next) => {
  console.error('❌ Error:', err);
  
  if (appInsights.defaultClient) {
    appInsights.defaultClient.trackException({ exception: err });
  }
  
  res.status(500).json({ 
    error: 'Internal Server Error',
    message: err.message 
  });
});

// 404ハンドリング
app.use((req, res) => {
  res.status(404).json({ 
    error: 'Not Found',
    path: req.path 
  });
});

// サーバー起動
app.listen(port, () => {
  console.log(`🚀 Server running on port ${port}`);
  console.log(`📊 Environment: ${process.env.NODE_ENV || 'development'}`);
  console.log(`🔑 Key Vault: ${keyVaultUrl || 'not configured'}`);
  console.log(`📈 App Insights: ${connectionString ? 'enabled' : 'disabled'}`);
});

// Graceful shutdown
process.on('SIGTERM', () => {
  console.log('SIGTERM received, shutting down gracefully...');
  if (appInsights.defaultClient) {
    appInsights.defaultClient.flush();
  }
  process.exit(0);
});

module.exports = app;  // テスト用にエクスポート
