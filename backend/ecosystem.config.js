module.exports = {
  apps: [
    {
      name: 'ecommerce',
      script: 'server.js',
      cwd: '/app/ecommerce/backend',
      instances: 'max',
      exec_mode: 'cluster',
      watch: false,
      max_memory_restart: '400M',
      env_production: {
        NODE_ENV: 'production',
        PORT: 3000,
      },
      error_file: '/var/log/pm2/ecommerce-error.log',
      out_file: '/var/log/pm2/ecommerce-out.log',
      log_date_format: 'YYYY-MM-DD HH:mm:ss Z',
      merge_logs: true,
      autorestart: true,
      restart_delay: 3000,
      max_restarts: 10,
      min_uptime: '10s',
    },
  ],
};
