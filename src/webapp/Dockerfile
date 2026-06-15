FROM node:26-alpine

# アプリケーションディレクトリを作成
WORKDIR /app

# npm本体の依存関係に対する脆弱性修正を取り込む
ARG NPM_VERSION=11.6.2
RUN npm install -g npm@${NPM_VERSION}

# package.jsonとpackage-lock.jsonをコピー
COPY package*.json ./

# 本番用の依存関係のみインストール
RUN npm ci --omit=dev && \
    npm cache clean --force

# アプリケーションのソースをコピー
COPY . .

# 非rootユーザーで実行
RUN addgroup -g 1001 -S nodejs && \
    adduser -S nodejs -u 1001 && \
    chown -R nodejs:nodejs /app

USER nodejs

# ポート公開
EXPOSE 3000

# ヘルスチェック
HEALTHCHECK --interval=30s --timeout=3s --start-period=40s --retries=3 \
  CMD node -e "require('http').get('http://localhost:3000/health', (r) => {process.exit(r.statusCode === 200 ? 0 : 1)})"

# アプリケーション起動
CMD ["npm", "start"]
