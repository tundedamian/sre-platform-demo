const express = require('express');
const client = require('prom-client');
const { createLogger, format, transports } = require('winston');

// Create express app
const app = express();
const PORT = process.env.PORT || 3000;

// Set up logger
const logger = createLogger({
  level: 'info',
  format: format.combine(
    format.timestamp(),
    format.errors({ stack: true }),
    format.splat(),
    format.json()
  ),
  defaultMeta: { service: 'sre-platform-app' },
  transports: [
    new transports.Console({
      format: format.combine(
        format.colorize(),
        format.simple()
      )
    })
  ]
});

// Register Prometheus client
const register = new client.Registry();

// Create custom metrics
const httpRequestDuration = new client.Histogram({
  name: 'http_request_duration_seconds',
  help: 'Duration of HTTP requests in seconds',
  labelNames: ['method', 'route', 'status'],
  registers: [register]
});

const httpRequestTotal = new client.Counter({
  name: 'http_requests_total',
  help: 'Total number of HTTP requests',
  labelNames: ['method', 'route', 'status'],
  registers: [register]
});

const appUptime = new client.Gauge({
  name: 'app_uptime_seconds',
  help: 'Application uptime in seconds',
  registers: [register]
});

// Middleware to collect metrics
app.use((req, res, next) => {
  const start = Date.now();
  
  res.on('finish', () => {
    const duration = (Date.now() - start) / 1000; // Convert to seconds
    const route = req.path;
    
    httpRequestDuration
      .labels(req.method, route, res.statusCode)
      .observe(duration);
    
    httpRequestTotal
      .labels(req.method, route, res.statusCode)
      .inc();
    
    logger.info(`${req.method} ${route} ${res.statusCode} - ${duration}s`);
  });
  
  next();
});

// Update uptime gauge every second
let uptimeSeconds = 0;
setInterval(() => {
  uptimeSeconds++;
  appUptime.set(uptimeSeconds);
}, 1000);

// Routes
app.get('/', (req, res) => {
  res.json({
    message: 'Welcome to the SRE Platform Demo',
    timestamp: new Date().toISOString(),
    status: 'healthy'
  });
});

app.get('/health', (req, res) => {
  res.status(200).json({
    status: 'healthy',
    uptime: process.uptime(),
    timestamp: new Date().toISOString()
  });
});

app.get('/metrics', async (req, res) => {
  try {
    res.set('Content-Type', register.contentType);
    res.end(await register.metrics());
  } catch (ex) {
    res.status(500).end(ex);
  }
});

app.get('/api/status', (req, res) => {
  const status = {
    service: 'sre-platform-app',
    version: '1.0.0',
    status: 'operational',
    timestamp: new Date().toISOString(),
    dependencies: {
      database: 'connected',
      cache: 'available',
      external_api: 'available'
    }
  };
  
  res.json(status);
});

// Simulate a slow endpoint for testing
app.get('/slow', (req, res) => {
  // Simulate processing time between 100-500ms
  const delay = Math.floor(Math.random() * 400) + 100;
  
  setTimeout(() => {
    res.json({
      message: `Slow endpoint completed after ${delay}ms`,
      delay: delay
    });
  }, delay);
});

// Simulate an error endpoint for testing
app.get('/error', (req, res) => {
  const shouldError = Math.random() > 0.7; // 30% chance of error
  
  if (shouldError) {
    logger.error('Simulated error endpoint triggered');
    res.status(500).json({
      error: 'Simulated server error for testing'
    });
  } else {
    res.json({
      message: 'Success - no error this time'
    });
  }
});

// Fallback for undefined routes
app.use('*', (req, res) => {
  res.status(404).json({
    error: 'Route not found',
    path: req.path
  });
});

// Error handling middleware
app.use((err, req, res, next) => {
  logger.error('Unhandled application error:', err);
  res.status(500).json({
    error: 'Internal server error'
  });
});

// Graceful shutdown
process.on('SIGTERM', () => {
  logger.info('Received SIGTERM, shutting down gracefully');
  server.close(() => {
    logger.info('Process terminated');
  });
});

process.on('SIGINT', () => {
  logger.info('Received SIGINT, shutting down gracefully');
  server.close(() => {
    logger.info('Process terminated');
  });
});

// Start server
const server = app.listen(PORT, () => {
  logger.info(`SRE Platform Demo server running on port ${PORT}`);
  logger.info(`Health check available at /health`);
  logger.info(`Metrics available at /metrics`);
});

module.exports = app;