const request = require('supertest');
const app = require('../app');

describe('AZ-400 Web App Tests', () => {
  describe('GET /', () => {
    it('should return 200 OK', async () => {
      const res = await request(app).get('/');
      expect(res.statusCode).toBe(200);
      expect(res.text).toContain('AZ-400 Handson Web App');
    });
  });

  describe('GET /health', () => {
    it('should return health status', async () => {
      const res = await request(app).get('/health');
      expect(res.statusCode).toBe(200);
      expect(res.body).toHaveProperty('status', 'healthy');
      expect(res.body).toHaveProperty('timestamp');
      expect(res.body).toHaveProperty('uptime');
    });

    it('should include configuration info', async () => {
      const res = await request(app).get('/health');
      expect(res.body).toHaveProperty('keyVault');
      expect(res.body).toHaveProperty('appInsights');
    });
  });

  describe('GET /info', () => {
    it('should return application info', async () => {
      const res = await request(app).get('/info');
      expect(res.statusCode).toBe(200);
      expect(res.body).toHaveProperty('name', 'AZ-400 Handson Web App');
      expect(res.body).toHaveProperty('version', '1.0.0');
      expect(res.body).toHaveProperty('nodeVersion');
    });
  });

  describe('GET /secret', () => {
    it('should return 500 if Key Vault not configured', async () => {
      // Key Vault URLが設定されていない場合のテスト
      if (!process.env.KEY_VAULT_URL) {
        const res = await request(app).get('/secret');
        expect(res.statusCode).toBe(500);
        expect(res.body).toHaveProperty('error');
      }
    });
  });

  describe('GET /404', () => {
    it('should return 404 for unknown routes', async () => {
      const res = await request(app).get('/unknown-route');
      expect(res.statusCode).toBe(404);
      expect(res.body).toHaveProperty('error', 'Not Found');
    });
  });
});
