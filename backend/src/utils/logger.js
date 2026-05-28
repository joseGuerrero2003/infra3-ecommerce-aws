const { createLogger, format, transports } = require('winston');

const logger = createLogger({
  level: process.env.LOG_LEVEL || 'info',
  format: format.combine(
    format.timestamp({ format: 'YYYY-MM-DD HH:mm:ss' }),
    format.errors({ stack: true }),
    format.json()
  ),
  defaultMeta: { service: 'ecommerce-api' },
  transports: [
    new transports.Console({
      format: format.combine(
        format.colorize(),
        format.printf(({ timestamp, level, message, ...meta }) => {
          const extra = Object.keys(meta).length ? JSON.stringify(meta) : '';
          return `${timestamp} [${level}]: ${message} ${extra}`;
        })
      ),
    }),
  ],
});

if (process.env.NODE_ENV === 'production' && process.env.CLOUDWATCH_LOG_GROUP) {
  try {
    const WinstonCloudWatch = require('winston-cloudwatch');
    logger.add(
      new WinstonCloudWatch({
        logGroupName: process.env.CLOUDWATCH_LOG_GROUP,
        logStreamName: `api-${new Date().toISOString().split('T')[0]}`,
        awsRegion: process.env.AWS_REGION || 'us-east-1',
        jsonMessage: true,
      })
    );
  } catch (_) {}
}

module.exports = logger;
