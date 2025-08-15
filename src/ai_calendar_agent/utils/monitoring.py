import logging
import time
import structlog
from prometheus_client import Counter, Histogram, Gauge, start_http_server
from typing import Dict, Any
import json
from datetime import datetime

# Prometheus Metrics
EVENTS_PROCESSED = Counter(
    'ai_calendar_events_processed_total',
    'Total events processed',
    ['source_type', 'status']
)

PROCESSING_TIME = Histogram(
    'ai_calendar_processing_seconds',
    'Time spent processing events',
    ['operation_type']
)

CALENDAR_OPERATIONS = Counter(
    'ai_calendar_operations_total',
    'Calendar operations performed',
    ['operation', 'status']
)

API_CALLS = Counter(
    'ai_calendar_api_calls_total',
    'External API calls made',
    ['service', 'endpoint', 'status_code']
)

SYSTEM_HEALTH = Gauge(
    'ai_calendar_system_health',
    'System health status (1=healthy, 0=unhealthy)',
    ['component']
)

class StructuredLogger:
    def __init__(self):
        # Configure structured logging
        structlog.configure(
            processors=[
                structlog.processors.TimeStamper(fmt="ISO"),
                structlog.processors.add_log_level,
                structlog.processors.JSONRenderer()
            ],
            wrapper_class=structlog.make_filtering_bound_logger(
                logging.INFO
            ),
            logger_factory=structlog.WriteLoggerFactory(),
            cache_logger_on_first_use=True,
        )
        self.logger = structlog.get_logger()

    def log_event_processing(
        self,
        event_type: str,
        source: str,
        status: str,
        processing_time: float,
        metadata: Dict[str, Any] = None
    ):
        """Log event processing with structured data"""
        log_data = {
            "event": "event_processing",
            "event_type": event_type,
            "source": source,
            "status": status,
            "processing_time_seconds": processing_time,
            "timestamp": datetime.utcnow().isoformat()
        }
        
        if metadata:
            log_data.update(metadata)

        # Update Prometheus metrics
        EVENTS_PROCESSED.labels(source_type=source, status=status).inc()
        PROCESSING_TIME.labels(operation_type=event_type).observe(processing_time)

        self.logger.info("Event processed", **log_data)

    def log_calendar_operation(
        self,
        operation: str,
        status: str,
        event_title: str = None,
        error: str = None
    ):
        """Log calendar operations"""
        log_data = {
            "event": "calendar_operation",
            "operation": operation,
            "status": status,
            "timestamp": datetime.utcnow().isoformat()
        }

        if event_title:
            log_data["event_title"] = event_title
        if error:
            log_data["error"] = error

        # Update Prometheus metrics
        CALENDAR_OPERATIONS.labels(operation=operation, status=status).inc()

        self.logger.info("Calendar operation", **log_data)

    def log_api_call(
        self,
        service: str,
        endpoint: str,
        status_code: int,
        response_time: float,
        error: str = None
    ):
        """Log external API calls"""
        log_data = {
            "event": "api_call",
            "service": service,
            "endpoint": endpoint,
            "status_code": status_code,
            "response_time_seconds": response_time,
            "timestamp": datetime.utcnow().isoformat()
        }

        if error:
            log_data["error"] = error

        # Update Prometheus metrics
        API_CALLS.labels(
            service=service,
            endpoint=endpoint,
            status_code=status_code
        ).inc()

        self.logger.info("API call", **log_data)

# Initialize monitoring
monitoring = StructuredLogger()
