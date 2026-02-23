module.exports = {
  apps: [
    {
      name: "loom-bridge",
      script: "loom-bridge.mjs",
      cwd: __dirname,
      env: {
        OPENCLAW_URL: "http://127.0.0.1:18789",
        OPENCLAW_PASSWORD: "<your-password>",
        CONVEX_SITE_URL: "https://kindhearted-goldfish-658.convex.site",
        WEBHOOK_SECRET: "<your-webhook-secret>",
        USER_TIMEZONE: "America/Phoenix",
      },
      restart_delay: 5000,
      max_restarts: 50,
      autorestart: true,
    },
  ],
};
