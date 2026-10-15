"""Stable local service-state documents, separate from model catalog metadata."""
from server.api import json_escape_string


def service_liveness() -> String:
    """A reachable request loop is alive; this makes no model claim."""
    return '{"schema_version":1,"status":"ok","scope":"process"}'


def model_readiness(ready: Bool, name: String, digest: String,
                    profile: String, context: Int) -> String:
    """Report the one resident session, not all catalog-listed models."""
    return ('{"schema_version":1,"status":"' +
            ('ready' if ready else 'not_ready') +
            '","ready":' + ('true' if ready else 'false') +
            ',"model":"' + json_escape_string(name) +
            '","digest":"' + json_escape_string(digest) +
            '","backend":"cuda","profile":"' + json_escape_string(profile) +
            '","context":' + String(context) + '}')
